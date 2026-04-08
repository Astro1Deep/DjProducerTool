import sys
import os
import pytest
from pathlib import Path

# Add root directory to path to allow importing modules from root
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from playlist_builder import build

def test_build_playlist_single_dir(tmp_path, capsys):
    # Setup
    base_dir = tmp_path / "music"
    base_dir.mkdir()
    
    # Create audio files
    (base_dir / "track1.mp3").touch()
    (base_dir / "track2.wav").touch()
    (base_dir / "notes.txt").touch() # Should be ignored
    
    # Execute
    build(str(base_dir))
    
    # Verify
    playlist_file = base_dir / "playlist.m3u8"
    assert playlist_file.exists()
    
    content = playlist_file.read_text()
    assert "track1.mp3" in content
    assert "track2.wav" in content
    assert "notes.txt" not in content
    
    captured = capsys.readouterr()
    assert f"Created {playlist_file}" in captured.out

def test_build_playlist_nested(tmp_path):
    # Setup
    base_dir = tmp_path / "collection"
    base_dir.mkdir()
    
    album_dir = base_dir / "album"
    album_dir.mkdir()
    (album_dir / "song.flac").touch()
    
    empty_dir = base_dir / "empty"
    empty_dir.mkdir()
    
    # Execute
    build(str(base_dir))
    
    # Verify
    assert (album_dir / "playlist.m3u8").exists()
    assert "song.flac" in (album_dir / "playlist.m3u8").read_text()
    
    assert not (empty_dir / "playlist.m3u8").exists()

def test_build_playlist_no_audio(tmp_path):
    # Setup
    base_dir = tmp_path / "docs"
    base_dir.mkdir()
    (base_dir / "readme.md").touch()
    
    # Execute
    build(str(base_dir))
    
    # Verify
    assert not (base_dir / "playlist.m3u8").exists()
