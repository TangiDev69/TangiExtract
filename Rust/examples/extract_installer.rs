use std::{env, path::Path};

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() != 3 {
        eprintln!("usage: extract_installer <installer.exe> <output-directory>");
        std::process::exit(2);
    }
    if let Err(error) = tangiextract::installers::nsis::extract_installer(
        Path::new(&args[1]),
        Path::new(&args[2]),
    ) {
        eprintln!("{error}");
        std::process::exit(1);
    }
}
