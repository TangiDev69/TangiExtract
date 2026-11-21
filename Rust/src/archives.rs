use std::{collections::HashSet, ffi::{CStr,c_char}, fs::{self,File}, io, path::{Component,Path}, ptr};
use zip::ZipArchive;
const MAX_INPUT:u64=1024*1024*1024;
const MAX_OUTPUT:u64=2*1024*1024*1024;
const MAX_ENTRY:u64=512*1024*1024;
const MAX_FILES:usize=100_000;
fn write_error(out:*mut c_char,cap:usize,msg:&str){if out.is_null()||cap==0{return}let b=msg.as_bytes();let n=b.len().min(cap-1);unsafe{ptr::copy_nonoverlapping(b.as_ptr(),out.cast::<u8>(),n);*out.add(n)=0;}}
pub fn extract_zip(input:&Path,output:&Path)->Result<(),String>{
 let meta=fs::metadata(input).map_err(|e|format!("Cannot read ZIP: {e}"))?;
 if meta.len()==0||meta.len()>MAX_INPUT{return Err("ZIP is empty or exceeds the 1 GB input limit.".into())}
 let file=File::open(input).map_err(|e|format!("Cannot open ZIP: {e}"))?;
 let mut archive=ZipArchive::new(file).map_err(|e|format!("Invalid or unsupported ZIP archive: {e}"))?;
 if archive.len()>MAX_FILES{return Err("ZIP contains too many entries.".into())}
 fs::create_dir_all(output).map_err(|e|format!("Cannot create output folder: {e}"))?;
 let mut seen=HashSet::new();let mut total=0u64;
 for i in 0..archive.len(){
  let mut entry=archive.by_index(i).map_err(|e|format!("Cannot read ZIP entry: {e}"))?;
  let rel=entry.enclosed_name().ok_or_else(||format!("Unsafe ZIP path rejected: {}",entry.name()))?.to_path_buf();
  if rel.as_os_str().is_empty(){continue}
  if rel.components().any(|c|!matches!(c,Component::Normal(_))){return Err(format!("Unsafe ZIP path rejected: {}",entry.name()))}
  if entry.unix_mode().is_some_and(|m|m&0o170000==0o120000){return Err(format!("Symbolic links are not extracted: {}",entry.name()))}
  if !seen.insert(rel.clone()){return Err(format!("Duplicate ZIP destination rejected: {}",entry.name()))}
  let dest=output.join(&rel);
  if entry.is_dir(){fs::create_dir_all(&dest).map_err(|e|format!("Cannot create folder: {e}"))?;continue}
  let declared=entry.size();
  if declared>MAX_ENTRY||declared>MAX_OUTPUT||total>MAX_OUTPUT-declared{return Err("Expanded ZIP data exceeds the configured safety limit.".into())}
  if let Some(parent)=dest.parent(){fs::create_dir_all(parent).map_err(|e|format!("Cannot create folder: {e}"))?}
  let mut out=File::create(&dest).map_err(|e|format!("Cannot create file: {e}"))?;
  let copied=io::copy(&mut entry,&mut out).map_err(|e|format!("Cannot extract {}: {e}",rel.display()))?;
  if copied!=declared||copied>MAX_ENTRY{return Err(format!("ZIP entry size mismatch or limit exceeded: {}",rel.display()))}
  total=total.checked_add(copied).ok_or("ZIP size counter overflow.")?;
  if total>MAX_OUTPUT{return Err("Expanded ZIP data exceeds the 2 GB safety limit.".into())}
 } Ok(())
}
#[unsafe(no_mangle)]
pub unsafe extern "C" fn tangiextract_zip_extract(input:*const c_char,output:*const c_char,error:*mut c_char,cap:usize)->i32{
 if input.is_null()||output.is_null(){write_error(error,cap,"Invalid input or output path.");return 1}
 let i=unsafe{CStr::from_ptr(input)}.to_string_lossy();let o=unsafe{CStr::from_ptr(output)}.to_string_lossy();
 match extract_zip(Path::new(i.as_ref()),Path::new(o.as_ref())){Ok(())=>0,Err(e)=>{write_error(error,cap,&e);1}}
}
#[cfg(test)] mod tests{
 use super::*;use std::{io::Write,time::{SystemTime,UNIX_EPOCH}};use zip::{write::SimpleFileOptions,ZipWriter};
 #[test]fn extracts_zip_entry(){let n=SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_nanos();let root=std::env::temp_dir().join(format!("tangi-zip-{n}"));fs::create_dir_all(&root).unwrap();let input=root.join("sample.zip");let output=root.join("out");{let f=File::create(&input).unwrap();let mut w=ZipWriter::new(f);w.start_file("data/hello.txt",SimpleFileOptions::default()).unwrap();w.write_all(b"hello tangi").unwrap();w.finish().unwrap();}extract_zip(&input,&output).unwrap();assert_eq!(fs::read(output.join("data/hello.txt")).unwrap(),b"hello tangi");fs::remove_dir_all(root).unwrap();}
}
use std::io::Read;

fn extract_tar_reader<R: Read>(reader: R, output: &Path) -> Result<(), String> {
    let mut archive = tar::Archive::new(reader);
    fs::create_dir_all(output).map_err(|e| format!("Cannot create output folder: {e}"))?;
    let entries = archive.entries().map_err(|e| format!("Invalid TAR archive: {e}"))?;
    let mut total = 0u64;
    let mut count = 0usize;
    for item in entries {
        let mut entry = item.map_err(|e| format!("Cannot read TAR entry: {e}"))?;
        count += 1;
        if count > MAX_FILES { return Err("Archive contains too many entries.".into()); }
        let path = entry.path().map_err(|e| format!("Invalid TAR path: {e}"))?.into_owned();
        if path.as_os_str().is_empty() { continue; }
        if path.is_absolute() || path.components().any(|c| !matches!(c, Component::Normal(_))) {
            return Err(format!("Unsafe TAR path rejected: {}", path.display()));
        }
        let kind = entry.header().entry_type();
        let destination = output.join(&path);
        if kind.is_dir() {
            fs::create_dir_all(&destination).map_err(|e| format!("Cannot create folder: {e}"))?;
            continue;
        }
        if !kind.is_file() { return Err(format!("Links and special TAR entries are not extracted: {}", path.display())); }
        let declared = entry.header().size().map_err(|e| format!("Invalid TAR entry size: {e}"))?;
        if declared > MAX_ENTRY || total > MAX_OUTPUT.saturating_sub(declared) {
            return Err("Expanded archive data exceeds the configured safety limit.".into());
        }
        if let Some(parent) = destination.parent() {
            fs::create_dir_all(parent).map_err(|e| format!("Cannot create folder: {e}"))?;
        }
        let mut out = File::create(&destination).map_err(|e| format!("Cannot create file: {e}"))?;
        let copied = io::copy(&mut entry, &mut out).map_err(|e| format!("Cannot extract {}: {e}", path.display()))?;
        if copied != declared { return Err(format!("TAR entry size mismatch: {}", path.display())); }
        total = total.checked_add(copied).ok_or("Archive size counter overflow.")?;
    }
    Ok(())
}

pub fn extract_tar(input: &Path, output: &Path, gzip: bool) -> Result<(), String> {
    let meta = fs::metadata(input).map_err(|e| format!("Cannot read archive: {e}"))?;
    if meta.len() == 0 || meta.len() > MAX_INPUT { return Err("Archive is empty or exceeds the 1 GB input limit.".into()); }
    let file = File::open(input).map_err(|e| format!("Cannot open archive: {e}"))?;
    if gzip { extract_tar_reader(flate2::read::GzDecoder::new(file), output) }
    else { extract_tar_reader(file, output) }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn tangiextract_tar_extract(input: *const c_char, output: *const c_char, gzip: i32, error: *mut c_char, cap: usize) -> i32 {
    if input.is_null() || output.is_null() { write_error(error, cap, "Invalid input or output path."); return 1; }
    let i = unsafe { CStr::from_ptr(input) }.to_string_lossy();
    let o = unsafe { CStr::from_ptr(output) }.to_string_lossy();
    match extract_tar(Path::new(i.as_ref()), Path::new(o.as_ref()), gzip != 0) {
        Ok(()) => 0,
        Err(e) => { write_error(error, cap, &e); 1 }
    }
}
