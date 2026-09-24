import asyncio
from app.services.storage import MinioStorageService

async def test():
    s = MinioStorageService()

    url = await s.upload_bytes(
        b"MEDAL-MINIO-TEST",
        "minio_test.txt",
        "text/plain"
    )

    print("Uploaded URL:", url)

asyncio.run(test())