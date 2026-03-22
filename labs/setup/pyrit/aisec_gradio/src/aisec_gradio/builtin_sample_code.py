"""Sample code shown in the UI for Built-in Datasets (aligned with PyRIT docs)."""

# Displayed in gr.Code — mirrors patterns from:
# https://azure.github.io/PyRIT/code/datasets/loading-datasets/

BUILTIN_DATASETS_SAMPLE = '''\
# List registered built-in dataset names (sync API in this PyRIT build)
from pyrit.datasets import SeedDatasetProvider

names = SeedDatasetProvider.get_all_dataset_names()
print("Built-in dataset names (sample):")
for n in names[:30]:
    print(f"  - {n}")
if len(names) > 30:
    print(f"  ... and {len(names) - 30} more")

# Async fetch of specific datasets (may download / use cache — use intentionally):
# import asyncio
# from pyrit.datasets import SeedDatasetProvider
#
# async def main():
#     datasets = await SeedDatasetProvider.fetch_datasets_async(
#         dataset_names=["airt_illegal", "airt_malware"],
#     )
#     for ds in datasets:
#         for seed in ds.seeds[:3]:
#             print(seed.value)
#
# asyncio.run(main())
'''
