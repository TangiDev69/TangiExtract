// NSIS extraction compatibility baseline. The upstream parser currently
// reads the installer and each decompressed entry into memory and applies
// its existing file-type filtering. These behaviors are retained for the
// initial integration and will be improved in separately tested changes.

use nsis::NsisInstaller;
use std::{
    ffi::{CStr, c_char},
    fs,
    path::{Component, Path},
    ptr,
};

const MAX_INPUT: u64 = 256 * 1024 * 1024;
const MAX_OUTPUT: u64 = 2 * 1024 * 1024 * 1024;
const MAX_FILES: usize = 100_000;

fn write_error(out: *mut c_char, capacity: usize, message: &str) {
    if out.is_null() || capacity == 0 {
        return;
    }
    let bytes = message.as_bytes();
    let count = bytes.len().min(capacity - 1);
    unsafe {
        ptr::copy_nonoverlapping(bytes.as_ptr(), out.cast::<u8>(), count);
        *out.add(count) = 0;
    }
}

pub fn extract_installer(input: &Path, output: &Path) -> Result<(), String> {
    let metadata = fs::metadata(input).map_err(|e| format!("Cannot read installer: {e}"))?;
    if metadata.len() == 0 || metadata.len() > MAX_INPUT {
        return Err("Installer is empty or exceeds the 256 MB safety limit.".into());
    }
    let bytes = fs::read(input).map_err(|e| format!("Cannot read installer: {e}"))?;
    let installer = NsisInstaller::from_bytes(&bytes)
        .map_err(|e| format!("Not a supported NSIS installer: {e}"))?;
    fs::create_dir_all(output).map_err(|e| format!("Cannot create extraction folder: {e}"))?;

    let mut total = 0u64;
    let mut count = 0usize;
    for item in installer.files() {
        let file = item.map_err(|e| format!("Cannot read installer file table: {e}"))?;
        count += 1;
        if count > MAX_FILES {
            return Err("Installer contains too many files.".into());
        }
        let relative = file
            .dest_path()
            .map_err(|e| format!("Invalid installer filename: {e}"))?
            .to_path();
        if relative.is_empty() {
            continue;
        }
        let relative = relative.replace('\\', "/");
        let rel_path = Path::new(&relative);
        if rel_path.is_absolute()
            || rel_path
                .components()
                .any(|c| !matches!(c, Component::Normal(_)))
        {
            return Err(format!("Unsafe installer path rejected: {relative}"));
        }
        // Repeated NSIS destinations are valid. Later section writes replace earlier files,
        // matching the installer's normal overwrite semantics. Payloads are never executed.
        let data = file
            .decompress()
            .map_err(|e| format!("Cannot decompress {relative}: {e}"))?;
        let size = data.len() as u64;
        if size > MAX_OUTPUT || total > MAX_OUTPUT - size {
            return Err("Expanded installer data exceeds the 2 GB safety limit.".into());
        }
        total += size;
        let destination = output.join(rel_path);
        if let Some(parent) = destination.parent() {
            fs::create_dir_all(parent)
                .map_err(|e| format!("Cannot create extraction folder: {e}"))?;
        }
        fs::write(&destination, data).map_err(|e| format!("Cannot write {relative}: {e}"))?;
    }
    if count == 0 {
        return Err("The installer contains no extractable files.".into());
    }
    Ok(())
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn tangiextract_nsis_extract(
    input_path: *const c_char,
    output_path: *const c_char,
    error_buffer: *mut c_char,
    error_capacity: usize,
) -> i32 {
    if input_path.is_null() || output_path.is_null() {
        write_error(error_buffer, error_capacity, "Invalid input or output path.");
        return 1;
    }
    let input = unsafe { CStr::from_ptr(input_path) }.to_string_lossy();
    let output = unsafe { CStr::from_ptr(output_path) }.to_string_lossy();
    match extract_installer(Path::new(input.as_ref()), Path::new(output.as_ref())) {
        Ok(()) => 0,
        Err(error) => {
            write_error(error_buffer, error_capacity, &error);
            1
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn refuses_missing_installer() {
        let out = std::env::temp_dir().join(format!("tangiextract-nsis-test-{}", std::process::id()));
        let result = extract_installer(Path::new("/definitely/not/an/installer.exe"), &out);
        assert!(result.is_err());
    }

    #[test]
    fn rejects_null_ffi_paths() {
        let mut error = [0i8; 128];
        let result = unsafe {
            tangiextract_nsis_extract(std::ptr::null(), std::ptr::null(), error.as_mut_ptr(), error.len())
        };
        assert_eq!(result, 1);
        assert!(!error.iter().all(|byte| *byte == 0));
    }
}
