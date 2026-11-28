use std::{collections::HashSet, ffi::{CStr,c_char}, fs::{self,File}, io, path::{Component,Path}, ptr};
use zip::ZipArchive;
const MAX_INPUT:u64=2*1024*1024*1024;
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

pub fn extract_tar(input: &Path, output: &Path, compression: i32) -> Result<(), String> {
    let meta = fs::metadata(input).map_err(|e| format!("Cannot read archive: {e}"))?;
    if meta.len() == 0 || meta.len() > MAX_INPUT { return Err("Archive is empty or exceeds the 1 GB input limit.".into()); }
    let file = File::open(input).map_err(|e| format!("Cannot open archive: {e}"))?;
    let reader: Box<dyn Read> = match compression {
        0 => Box::new(file),
        1 => Box::new(flate2::read::GzDecoder::new(file)),
        2 => Box::new(bzip2::read::BzDecoder::new(file)),
        3 => Box::new(xz2::read::XzDecoder::new(file)),
        4 => Box::new(zstd::stream::Decoder::new(file).map_err(|e| format!("Invalid Zstandard stream: {e}"))?),
        5 => Box::new(lz4_flex::frame::FrameDecoder::new(file)),
        _ => return Err("Unknown TAR compression type.".into()),
    };
    extract_tar_reader(reader, output)
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn tangiextract_tar_extract(input: *const c_char, output: *const c_char, compression: i32, error: *mut c_char, cap: usize) -> i32 {
    if input.is_null() || output.is_null() { write_error(error, cap, "Invalid input or output path."); return 1; }
    let i = unsafe { CStr::from_ptr(input) }.to_string_lossy();
    let o = unsafe { CStr::from_ptr(output) }.to_string_lossy();
    match extract_tar(Path::new(i.as_ref()), Path::new(o.as_ref()), compression) {
        Ok(()) => 0,
        Err(e) => { write_error(error, cap, &e); 1 }
    }
}

fn safe_relative(raw: &str, label: &str) -> Result<std::path::PathBuf, String> {
    let normalized = raw.replace('\\', "/");
    let path = Path::new(&normalized);
    if path.as_os_str().is_empty() || path.is_absolute()
        || path.components().any(|c| !matches!(c, Component::Normal(_))) {
        return Err(format!("Unsafe {label} path rejected: {raw}"));
    }
    Ok(path.to_path_buf())
}

fn sevenz_error(message: String) -> sevenz_rust2::Error {
    sevenz_rust2::Error::Other(std::borrow::Cow::Owned(message))
}

pub fn extract_7z(input: &Path, output: &Path) -> Result<(), String> {
    let meta = fs::metadata(input).map_err(|e| format!("Cannot read 7Z: {e}"))?;
    if meta.len() == 0 || meta.len() > MAX_INPUT {
        return Err("7Z archive is empty or exceeds the 1 GB input limit.".into());
    }
    fs::create_dir_all(output).map_err(|e| format!("Cannot create output folder: {e}"))?;
    let root = output.to_path_buf();
    let mut count = 0usize;
    let mut total = 0u64;
    sevenz_rust2::decompress_file_with_extract_fn(input, output, |entry, reader, _library_path| {
        count += 1;
        if count > MAX_FILES {
            return Err(sevenz_error("Archive contains too many entries.".into()));
        }
        let relative = safe_relative(&entry.name, "7Z").map_err(sevenz_error)?;
        let destination = root.join(relative);
        if entry.is_directory {
            fs::create_dir_all(&destination).map_err(|e| sevenz_error(e.to_string()))?;
            return Ok(true);
        }
        if entry.size > MAX_ENTRY || total > MAX_OUTPUT.saturating_sub(entry.size) {
            return Err(sevenz_error("Expanded 7Z data exceeds the configured safety limit.".into()));
        }
        if let Some(parent) = destination.parent() {
            fs::create_dir_all(parent).map_err(|e| sevenz_error(e.to_string()))?;
        }
        let mut file = File::create(&destination).map_err(|e| sevenz_error(e.to_string()))?;
        let copied = io::copy(&mut (&mut *reader).take(MAX_ENTRY + 1), &mut file)
            .map_err(|e| sevenz_error(e.to_string()))?;
        if copied != entry.size || copied > MAX_ENTRY {
            return Err(sevenz_error("7Z entry size mismatch or limit exceeded.".into()));
        }
        total = total.checked_add(copied)
            .ok_or_else(|| sevenz_error("7Z size counter overflow.".into()))?;
        Ok(true)
    }).map_err(|e| format!("Cannot extract 7Z archive: {e}"))
}



pub fn extract_cab(input: &Path, output: &Path) -> Result<(), String> {
    let meta = fs::metadata(input).map_err(|e| format!("Cannot read CAB: {e}"))?;
    if meta.len() == 0 || meta.len() > MAX_INPUT {
        return Err("CAB archive is empty or exceeds the 1 GB input limit.".into());
    }
    let file = File::open(input).map_err(|e| format!("Cannot open CAB: {e}"))?;
    let mut cabinet = cab::Cabinet::new(file).map_err(|e| format!("Invalid CAB archive: {e}"))?;
    fs::create_dir_all(output).map_err(|e| format!("Cannot create output folder: {e}"))?;
    let mut names = Vec::new();
    let mut seen = HashSet::new();
    let mut declared_total = 0u64;
    for folder in cabinet.folder_entries() {
        for entry in folder.file_entries() {
            let name = entry.name().to_string();
            let relative = safe_relative(&name, "CAB")?;
            if !seen.insert(relative.clone()) {
                return Err(format!("Duplicate CAB destination rejected: {}", relative.display()));
            }
            let size = u64::from(entry.uncompressed_size());
            if size > MAX_ENTRY || declared_total > MAX_OUTPUT.saturating_sub(size) {
                return Err("Expanded CAB data exceeds the configured safety limit.".into());
            }
            declared_total = declared_total.checked_add(size).ok_or("CAB size counter overflow.")?;
            names.push((name, relative, size));
            if names.len() > MAX_FILES {
                return Err("CAB archive contains too many entries.".into());
            }
        }
    }
    let mut total = 0u64;
    for (name, relative, declared) in names {
        let destination = output.join(&relative);
        if let Some(parent) = destination.parent() {
            fs::create_dir_all(parent).map_err(|e| format!("Cannot create CAB folder: {e}"))?;
        }
        let mut reader = cabinet.read_file(&name).map_err(|e| format!("Cannot read CAB entry {name}: {e}"))?;
        let mut out = File::create(&destination).map_err(|e| format!("Cannot create CAB file: {e}"))?;
        let copied = io::copy(&mut reader, &mut out).map_err(|e| format!("Cannot extract CAB entry {name}: {e}"))?;
        if copied != declared || copied > MAX_ENTRY || total > MAX_OUTPUT.saturating_sub(copied) {
            return Err(format!("CAB entry size mismatch or extraction limit exceeded: {name}"));
        }
        total = total.checked_add(copied).ok_or("CAB size counter overflow.")?;
    }
    Ok(())
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn tangiextract_cab_extract(input: *const c_char, output: *const c_char, error: *mut c_char, cap: usize) -> i32 {
    if input.is_null() || output.is_null() { write_error(error, cap, "Invalid input or output path."); return 1; }
    let i = unsafe { CStr::from_ptr(input) }.to_string_lossy();
    let o = unsafe { CStr::from_ptr(output) }.to_string_lossy();
    match extract_cab(Path::new(i.as_ref()), Path::new(o.as_ref())) {
        Ok(()) => 0,
        Err(e) => { write_error(error, cap, &e); 1 }
    }
}

// UnRAR license restriction: UnRAR source code may be used in software to handle
// RAR archives without limitations free of charge, but cannot be used to develop
// a RAR (WinRAR) compatible archiver or to re-create the proprietary RAR
// compression algorithm. See NOTICE for the full UnRAR license text.
pub fn extract_rar(input: &Path, output: &Path) -> Result<(), String> {
    let meta = fs::metadata(input).map_err(|e| format!("Cannot read RAR: {e}"))?;
    if meta.len() == 0 || meta.len() > MAX_INPUT {
        return Err("RAR archive is empty or exceeds the 1 GB input limit.".into());
    }
    fs::create_dir_all(output).map_err(|e| format!("Cannot create output folder: {e}"))?;
    let mut archive = unrar::Archive::new(input)
        .open_for_processing()
        .map_err(|e| format!("Cannot open RAR archive: {e}"))?;
    let mut count = 0usize;
    let mut total = 0u64;
    let mut seen = HashSet::new();

    loop {
        let next = archive.read_header().map_err(|e| format!("Cannot read RAR header: {e}"))?;
        let Some(mut current) = next else { break };
        let entry = current.entry().clone();
        count += 1;
        if count > MAX_FILES {
            return Err("RAR archive contains too many entries.".into());
        }
        if entry.is_encrypted() {
            return Err(format!("Encrypted RAR entries are not supported without a password: {}", entry.filename.display()));
        }
        if entry.is_split() {
            return Err("Multi-volume or split RAR entries are not supported yet.".into());
        }
        let relative = safe_relative(&entry.filename.to_string_lossy(), "RAR")?;
        if !seen.insert(relative.clone()) {
            return Err(format!("Duplicate RAR destination rejected: {}", relative.display()));
        }
        // Unix-mode attributes encode symlink file types in the high bits.
        if entry.file_attr & 0o170000 == 0o120000 {
            return Err(format!("RAR symbolic links are not extracted: {}", relative.display()));
        }
        let destination = output.join(&relative);
        if entry.is_directory() {
            fs::create_dir_all(&destination).map_err(|e| format!("Cannot create RAR folder: {e}"))?;
            archive = current.skip().map_err(|e| format!("Cannot skip RAR directory: {e}"))?;
            continue;
        }
        let unpacked_size = entry.unpacked_size;
        if unpacked_size > MAX_ENTRY || total > MAX_OUTPUT.saturating_sub(unpacked_size) {
            return Err("Expanded RAR data exceeds the configured safety limit.".into());
        }
        if let Some(parent) = destination.parent() {
            fs::create_dir_all(parent).map_err(|e| format!("Cannot create RAR folder: {e}"))?;
        }
        archive = current.extract_to(&destination)
            .map_err(|e| format!("Cannot extract RAR entry {}: {e}", relative.display()))?;
        total = total.checked_add(unpacked_size)
            .ok_or("RAR size counter overflow.")?;
    }
    Ok(())
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn tangiextract_rar_extract(input: *const c_char, output: *const c_char, error: *mut c_char, cap: usize) -> i32 {
    if input.is_null() || output.is_null() { write_error(error, cap, "Invalid input or output path."); return 1; }
    let i = unsafe { CStr::from_ptr(input) }.to_string_lossy();
    let o = unsafe { CStr::from_ptr(output) }.to_string_lossy();
    match extract_rar(Path::new(i.as_ref()), Path::new(o.as_ref())) {
        Ok(()) => 0,
        Err(e) => { write_error(error, cap, &e); 1 }
    }
}

pub fn extract_stream(input: &Path, output: &Path, kind: i32) -> Result<(), String> {
    let meta = fs::metadata(input).map_err(|e| format!("Cannot read compressed file: {e}"))?;
    if meta.len() == 0 || meta.len() > MAX_INPUT {
        return Err("Compressed file is empty or exceeds the 1 GB input limit.".into());
    }
    let file = File::open(input).map_err(|e| format!("Cannot open compressed file: {e}"))?;
    let reader: Box<dyn Read> = match kind {
        1 => Box::new(flate2::read::GzDecoder::new(file)),
        2 => Box::new(bzip2::read::BzDecoder::new(file)),
        3 => Box::new(xz2::read::XzDecoder::new(file)),
        4 => Box::new(zstd::stream::Decoder::new(file).map_err(|e| format!("Invalid Zstandard stream: {e}"))?),
        5 => Box::new(lz4_flex::frame::FrameDecoder::new(file)),
        _ => return Err("Unknown compression stream type.".into()),
    };
    if let Some(parent) = output.parent() {
        fs::create_dir_all(parent).map_err(|e| format!("Cannot create output folder: {e}"))?;
    }
    let mut out = File::create(output).map_err(|e| format!("Cannot create output file: {e}"))?;
    let copied = io::copy(&mut reader.take(MAX_OUTPUT + 1), &mut out)
        .map_err(|e| format!("Cannot decompress stream: {e}"))?;
    if copied > MAX_OUTPUT {
        let _ = fs::remove_file(output);
        return Err("Expanded compressed data exceeds the 2 GB safety limit.".into());
    }
    Ok(())
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn tangiextract_7z_extract(input: *const c_char, output: *const c_char, error: *mut c_char, cap: usize) -> i32 {
    if input.is_null() || output.is_null() { write_error(error, cap, "Invalid input or output path."); return 1; }
    let i = unsafe { CStr::from_ptr(input) }.to_string_lossy();
    let o = unsafe { CStr::from_ptr(output) }.to_string_lossy();
    match extract_7z(Path::new(i.as_ref()), Path::new(o.as_ref())) {
        Ok(()) => 0,
        Err(e) => { write_error(error, cap, &e); 1 }
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn tangiextract_stream_extract(input: *const c_char, output: *const c_char, kind: i32, error: *mut c_char, cap: usize) -> i32 {
    if input.is_null() || output.is_null() { write_error(error, cap, "Invalid input or output path."); return 1; }
    let i = unsafe { CStr::from_ptr(input) }.to_string_lossy();
    let o = unsafe { CStr::from_ptr(output) }.to_string_lossy();
    match extract_stream(Path::new(i.as_ref()), Path::new(o.as_ref()), kind) {
        Ok(()) => 0,
        Err(e) => { write_error(error, cap, &e); 1 }
    }
}



/// Convert an Inno destination template into a relative extraction path.
/// Inno destinations commonly begin with a root constant such as {app};
/// preserve that root as a named directory instead of writing outside output.
fn inno_destination_relative(raw: &str) -> Result<std::path::PathBuf, String> {
    let normalized = raw.replace('\\\\', "/");
    if normalized.starts_with('/')
        || normalized.as_bytes().get(1) == Some(&b':')
    {
        return Err(format!("Unsafe Inno Setup absolute destination rejected: {raw}"));
    }
    let mapped = normalized
        .split('/')
        .map(|component| {
            if component.starts_with('{') && component.ends_with('}') && component.len() > 2 {
                &component[1..component.len() - 1]
            } else {
                component
            }
        })
        .collect::<Vec<_>>()
        .join("/");
    safe_relative(&mapped, "Inno Setup")
}

/// Extract an Inno Setup installer using its real file-entry table.
pub fn extract_inno(
    input: &Path,
    output: &Path,
    progress: Option<extern "C" fn(u64, u64, *mut std::ffi::c_void)>,
    context: *mut std::ffi::c_void,
) -> Result<(), String> {
    use inno::Inno;
    let meta = fs::metadata(input).map_err(|e| format!("Cannot read Inno Setup installer: {e}"))?;
    if meta.len() == 0 || meta.len() > MAX_INPUT {
        return Err("Inno Setup installer is empty or exceeds the 2 GB input limit.".into());
    }
    let mut installer = Inno::open(input)
        .map_err(|e| format!("Not a supported Inno Setup installer, or its header is unsupported: {e}"))?;
    let mut files = installer.streaming_files(|_| true);
    let total = files.len() as u64;
    if total == 0 {
        return Err("The Inno Setup header contains no extractable file entries.".into());
    }
    fs::create_dir_all(output).map_err(|e| format!("Cannot create output folder: {e}"))?;
    let mut completed = 0u64;
    let mut total_written = 0u64;
    while let Some(item) = files.next() {
        let (entry, mut reader) = item
            .map_err(|e| format!("Cannot read Inno Setup file entry: {e}"))?;
        let Some(destination) = entry.file().destination() else {
            completed += 1;
            continue;
        };
        let relative = inno_destination_relative(destination)?;
        let target = output.join(&relative);
        if let Some(parent) = target.parent() {
            fs::create_dir_all(parent)
                .map_err(|e| format!("Cannot create Inno Setup folder {}: {e}", parent.display()))?;
        }
        let part = target.with_file_name(format!(
            ".tangiextract-{}-{}.part",
            completed,
            target.file_name().unwrap_or_default().to_string_lossy()
        ));
        let mut file = File::create(&part)
            .map_err(|e| format!("Cannot create {}: {e}", part.display()))?;
        let copied = match io::copy(&mut reader.take(MAX_ENTRY + 1), &mut file) {
            Ok(size) => size,
            Err(error) => {
                let _ = fs::remove_file(&part);
                return Err(format!("Cannot extract {} (checksum or data error): {error}", relative.display()));
            }
        };
        if copied > MAX_ENTRY || total_written > MAX_OUTPUT.saturating_sub(copied) {
            let _ = fs::remove_file(&part);
            return Err("Expanded Inno Setup data exceeds the configured 2 GB safety limit.".into());
        }
        total_written = total_written.checked_add(copied)
            .ok_or("Inno Setup extraction size counter overflow.")?;
        file.sync_all().map_err(|e| format!("Cannot finish {}: {e}", relative.display()))?;
        drop(file);
        if let Err(error) = fs::rename(&part, &target) {
            let _ = fs::remove_file(&part);
            return Err(format!("Cannot publish {}: {error}", relative.display()));
        }
        completed += 1;
        if let Some(callback) = progress {
            if completed % 16 == 0 || completed == total {
                callback(completed, total, context);
            }
        }
    }
    if completed == 0 {
        return Err("The Inno Setup installer contained no files that could be extracted.".into());
    }
    Ok(())
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn tangiextract_inno_extract(
    input: *const c_char,
    output: *const c_char,
    progress: Option<extern "C" fn(u64, u64, *mut std::ffi::c_void)>,
    context: *mut std::ffi::c_void,
    error: *mut c_char,
    cap: usize,
) -> i32 {
    if input.is_null() || output.is_null() {
        write_error(error, cap, "Invalid input or output path.");
        return 1;
    }
    let input = unsafe { CStr::from_ptr(input) }.to_string_lossy();
    let output = unsafe { CStr::from_ptr(output) }.to_string_lossy();
    match extract_inno(Path::new(input.as_ref()), Path::new(output.as_ref()), progress, context) {
        Ok(()) => 0,
        Err(message) => { write_error(error, cap, &message); 1 }
    }
}

/// Extended format engine for archive, disk-image, document and installer
/// containers not handled by the dedicated, already-tested extraction paths.
pub fn extract_extended(input: &Path, output: &Path) -> Result<(), String> {
    use exav_unpack::{detect, walk, Budget, Limits, Member};
    use exav_unpack::source::BlockCache;

    let meta = fs::metadata(input).map_err(|e| format!("Cannot read input: {e}"))?;
    if meta.len() == 0 || meta.len() > MAX_INPUT {
        return Err("Input is empty or exceeds the 1 GB input limit.".into());
    }
    let source = BlockCache::new(File::open(input).map_err(|e| format!("Cannot open input: {e}"))?)
        .map_err(|e| format!("Cannot prepare archive reader: {e}"))?;
    let format = detect(&source).ok_or_else(|| "This file type is not recognised by the extended extraction engine.".to_string())?;

    let mut limits = Limits::default();
    limits.max_extracted_bytes = 2 * 1024 * 1024 * 1024;
    limits.max_buffer_bytes = 128 * 1024 * 1024;
    limits.max_members = 50_000;
    limits.max_recursion = 8;
    let mut budget = Budget::new(limits);
    fs::create_dir_all(output).map_err(|e| format!("Cannot create output folder: {e}"))?;

    let mut seen = HashSet::new();
    let mut extracted = 0usize;
    let mut failure: Option<String> = None;

    let result = walk::<()>(format, &source, &mut budget, &mut |member, content, _budget| {
        if let Some(reason) = member.unsupported {
            failure = Some(format!("{} was recognised but could not be fully decoded: {reason}", member.name));
            return Some(());
        }

        let is_directory = member.name.ends_with('/')
            || member.mode.is_some_and(|mode| mode & 0o170000 == 0o040000);
        let trimmed_name = member.name.trim_end_matches('/');
        if trimmed_name.is_empty() {
            return None;
        }
        let relative = match safe_relative(trimmed_name, "extended archive") {
            Ok(path) => path,
            Err(error) => { failure = Some(error); return Some(()); }
        };
        if member.link.is_some()
            || member.mode.is_some_and(|mode| mode & 0o170000 == 0o120000)
        {
            failure = Some(format!("Symbolic links are not extracted: {}", member.name));
            return Some(());
        }
        if !seen.insert(relative.clone()) {
            failure = Some(format!("Duplicate extraction destination rejected: {}", relative.display()));
            return Some(());
        }
        let destination = output.join(&relative);

        if is_directory {
            if let Err(error) = fs::create_dir_all(&destination) {
                failure = Some(format!("Cannot create folder {}: {error}", relative.display()));
                return Some(());
            }
            return None;
        }

        let Some(content) = content else {
            // Some structured formats expose metadata without a file payload.
            return None;
        };
        if let Some(parent) = destination.parent() {
            if let Err(error) = fs::create_dir_all(parent) {
                failure = Some(format!("Cannot create folder: {error}"));
                return Some(());
            }
        }
        let mut file = match File::create(&destination) {
            Ok(file) => file,
            Err(error) => {
                failure = Some(format!("Cannot create {}: {error}", relative.display()));
                return Some(());
            }
        };
        let copied = match content {
            Member::Bytes(bytes) => {
                if let Err(error) = io::Write::write_all(&mut file, &bytes) {
                    failure = Some(format!("Cannot write {}: {error}", relative.display()));
                    return Some(());
                }
                bytes.len() as u64
            }
            Member::Stream(reader) => match io::copy(reader, &mut file) {
                Ok(size) => size,
                Err(error) => {
                    failure = Some(format!("Cannot extract {}: {error}", relative.display()));
                    return Some(());
                }
            },
        };
        let _ = copied;
        extracted += 1;
        None
    });

    if let Some(error) = failure {
        return Err(error);
    }
    result.map_err(|e| format!("Extended extraction stopped: {e}"))?;
    if extracted == 0 {
        return Err("The format was recognised, but no extractable file contents were found.".into());
    }
    Ok(())
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn tangiextract_extended_extract(
    input: *const c_char,
    output: *const c_char,
    error: *mut c_char,
    cap: usize,
) -> i32 {
    if input.is_null() || output.is_null() {
        write_error(error, cap, "Invalid input or output path.");
        return 1;
    }
    let input = unsafe { CStr::from_ptr(input) }.to_string_lossy();
    let output = unsafe { CStr::from_ptr(output) }.to_string_lossy();
    match extract_extended(Path::new(input.as_ref()), Path::new(output.as_ref())) {
        Ok(()) => 0,
        Err(message) => { write_error(error, cap, &message); 1 }
    }
}
