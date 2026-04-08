import datetime

from peewee import CharField, DateTimeField, FloatField, ForeignKeyField, IntegerField, Model, SqliteDatabase, TextField

try:
    from .config import Config
except ImportError:
    from core.config import Config  # type: ignore


db = SqliteDatabase(None)


class BaseModel(Model):
    class Meta:
        database = db


class Scan(BaseModel):
    id = CharField(primary_key=True)
    root_path = TextField()
    timestamp = DateTimeField(default=datetime.datetime.now)
    file_count = IntegerField(default=0)
    status = CharField(default="pending")


class FileIndex(BaseModel):
    path = TextField(unique=True)
    scan_id = ForeignKeyField(Scan, backref="files")
    rel_path = TextField()
    full_path = TextField()
    size_bytes = IntegerField()
    mtime = FloatField()
    sha256 = CharField(index=True, null=True)
    file_type = CharField(null=True)


class GlobalHash(BaseModel):
    sha256 = CharField(primary_key=True)
    first_seen_scan = ForeignKeyField(Scan)
    ref_count = IntegerField(default=1)


def init_db():
    Config.ensure_dirs()
    db.init(str(Config.DB_PATH))
    db.connect()
    db.create_tables([Scan, FileIndex, GlobalHash], safe=True)
    return db
