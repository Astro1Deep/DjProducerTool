import csv
import json
from pathlib import Path
from .db import db, Scan, FileIndex, GlobalHash, init_db

class Importer:
    def __init__(self):
        self.db = init_db()

    def import_scan_pack(self, scan_dir):
        scan_dir = Path(scan_dir)
        manifest_path = scan_dir / "manifest.json"
        csv_path = scan_dir / "files_index.csv"
        
        if not manifest_path.exists() or not csv_path.exists():
            raise FileNotFoundError("Invalid scan pack")
            
        with open(manifest_path, 'r') as f:
            manifest = json.load(f)
            
        with self.db.atomic():
            # Create Scan entry
            scan, created = Scan.get_or_create(
                id=manifest['scan_id'],
                defaults={
                    'root_path': manifest['root_path'],
                    'file_count': manifest['file_count'],
                    'status': 'imported'
                }
            )
            
            if not created:
                print(f"Scan {manifest['scan_id']} already imported.")
                # Optional: Delete existing files for this scan to re-import?
                # For now, skip.
                return

            print(f"Importing {manifest['file_count']} files for scan {scan.id}...")
            
            # Bulk insert files
            batch_size = 1000
            batch = []
            
            with open(csv_path, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    file_data = {
                        'scan_id': scan.id,
                        'rel_path': row['rel_path'],
                        'full_path': row['full_path'],
                        'size_bytes': int(row['size']),
                        'mtime': float(row['mtime']),
                        'sha256': row['sha256'] if row['sha256'] else None,
                        'file_type': row['type']
                    }
                    batch.append(file_data)
                    
                    # Update Global Hash Index
                    if file_data['sha256']:
                        try:
                            GlobalHash.insert(
                                sha256=file_data['sha256'],
                                first_seen_scan=scan,
                                ref_count=1
                            ).on_conflict(
                                conflict_target=[GlobalHash.sha256],
                                update={GlobalHash.ref_count: GlobalHash.ref_count + 1}
                            ).execute()
                        except:
                            pass # Handle gracefully

                    if len(batch) >= batch_size:
                        FileIndex.insert_many(batch).execute()
                        batch = []
                        print(".", end="", flush=True)
                
                if batch:
                    FileIndex.insert_many(batch).execute()
            
            print("\nImport complete.")
