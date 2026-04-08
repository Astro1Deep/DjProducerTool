from lib.ableton_sample_recovery import AdvancedSampleRecovery


def test_recovery_works_with_paths_containing_spaces(tmp_path):
    recovery = AdvancedSampleRecovery(base_path=str(tmp_path))

    library_dir = tmp_path / "Library With Spaces"
    library_dir.mkdir(parents=True)
    source_file = library_dir / "Kick 01.wav"
    source_file.write_bytes(b"RIFFfake-audio-data")

    db = recovery.build_sample_database(str(library_dir))
    file_hash = recovery._calculate_file_hash(source_file)

    target_dir = tmp_path / "Project Folder" / "Samples Missing"
    target_file = target_dir / source_file.name

    missing_samples = [
        {
            "name": source_file.name,
            "path": str(target_file),
            "hash": file_hash,
            "size": source_file.stat().st_size,
        }
    ]

    results = recovery.execute_recovery_plan(missing_samples, db)

    assert results["recovered"] == 1
    assert results["failed"] == 0
    assert target_file.exists()
    assert target_file.read_bytes() == source_file.read_bytes()


def test_recovery_uses_fallback_target_when_original_path_missing(tmp_path):
    recovery = AdvancedSampleRecovery(base_path=str(tmp_path))

    library_dir = tmp_path / "Library"
    library_dir.mkdir(parents=True)
    source_file = library_dir / "Snare 01.wav"
    source_file.write_bytes(b"RIFFfake-audio-data-2")

    db = recovery.build_sample_database(str(library_dir))
    file_hash = recovery._calculate_file_hash(source_file)

    missing_samples = [
        {
            "name": source_file.name,
            "path": "",
            "hash": file_hash,
            "size": source_file.stat().st_size,
        }
    ]

    results = recovery.execute_recovery_plan(missing_samples, db)
    fallback_target = tmp_path / "_Recovered_Samples" / source_file.name

    assert results["recovered"] == 1
    assert results["failed"] == 0
    assert fallback_target.exists()
    assert fallback_target.read_bytes() == source_file.read_bytes()
