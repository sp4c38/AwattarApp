# -*- coding: utf-8 -*-

"""Discovergy poller

Poll for data from different sources.

All functions that end with _task will be feed to the event loop.
"""
__author__ = "Frank Becker <fb@alien8.de>"
__copyright__ = "Frank Becker"
__license__ = "mit"

import asyncio

from pathlib import Path

import arrow  # type: ignore
from typing import Dict, List, Optional

from box import Box  # type: ignore
from loguru import logger as log

from . import awattar
from .config import read_config
from .defaults import CONVERT_MWH_KWH, Region, TIME_CORRECT
from .utils import start_logging, read_data, write_data


def transform_entry(entry: Box) -> Optional[Box]:
    """Return the data entry as the AWattPrice app expects it."""
    try:
        if entry.unit == "Eur/MWh":
            entry.pop("unit")
            # Divide through 1000 to not display miliseconds
            entry.start_timestamp = int(entry.start_timestamp / TIME_CORRECT)
            entry.end_timestamp = int(entry.end_timestamp / TIME_CORRECT)
            # Convert MWh to kWh
            entry.marketprice = entry.marketprice * CONVERT_MWH_KWH
    except KeyError:
        log.warning(f"Missing key in Awattar entry. Skipping: {entry}.")
    except Exception as e:
        log.warning(f"Bogus data in Awattar entry. Skipping: {entry}: {e}")
    else:
        return entry
    return None


async def awattar_read_task(
    *,
    config: Box,
    region: Region,
    start: Optional[int] = None,
    end: Optional[int] = None,
) -> Optional[List[Box]]:
    """Async worker to read the Awattar data. If too old, poll the
    Awattar API.
    """
    try:
        data = await awattar.get(config=config, region=region, start=start, end=end)
    except Exception as e:
        log.warning(f"Error in Awattar data poller: {e}")
    else:
        return data
    return None


async def await_tasks(tasks):
    """Gather the tasks."""
    return await asyncio.gather(*tasks)


async def get_data(config: Box, region: Optional[Region] = None, force: bool = False) -> Dict:
    """Request the Awattar data. Read it from file, if it is too old fetch it
    from the Awattar API endpoint.

    :param config: AWattPrice config
    :param force: Enforce fetching of data
    """
    if region is None:
        region = Region.DE
    # 1) Read the data file.
    file_path = Path(config.file_location.data_dir).expanduser() / Path(f"awattar-data-{region.name.lower()}.json")
    data = await read_data(file_path=file_path)
    fetched_data = None
    need_update = True
    last_update = 0
    now = arrow.utcnow()
    if data:
        last_update = data.meta.update_ts
        # Only poll every config.poll.awattar seconds
        if now.timestamp > last_update + int(config.poll.awattar):
            last_entry = max([d.start_timestamp for d in data.prices])
            need_update = any(
                [
                    now.timestamp > last_entry,
                    # Should trigger if there are less than this amount of future energy price points.
                    len([True for e in data.prices if e.start_timestamp > now.timestamp]) <
                        int(config.poll.if_less_than),
                ]
            )
        else:
            need_update = False
    if need_update or force:
        # By default the Awattar API returns data for the next 24h. It can provide
        # data until tomorrow midnight. Let's ask for that. Further, set the start
        # time to the last full hour. The Awattar API expects microsecond timestamps.
        start = now.replace(minute=0, second=0, microsecond=0).timestamp * TIME_CORRECT
        end = now.shift(days=+2).replace(hour=0, minute=0, second=0, microsecond=0).timestamp * TIME_CORRECT
        future = awattar_read_task(config=config, region=region, start=start, end=end)
        if future is None:
            return None
        results = await asyncio.gather(*[future])
        if results:
            log.info("Successfully fetched fresh data from Awattar.")
            # We run one task in asyncio
            fetched_data = results.pop()
        else:
            log.info("Failed to fetch fresh data from Awattar.")
            fetched_data = None
    else:
        log.debug("No need to update Awattar data from their API.")
    # Update existing data
    must_write_data = False
    if data and fetched_data:
        max_existing_data_start_timestamp = max([d.start_timestamp for d in data.prices]) * TIME_CORRECT
        for entry in fetched_data:
            ts = entry.start_timestamp
            if ts <= max_existing_data_start_timestamp:
                continue
            entry = transform_entry(entry)
            if entry:
                must_write_data = True
                data.prices.append(entry)
        if must_write_data:
            data.meta.update_ts = now.timestamp
    elif fetched_data:
        data = Box({"prices": [], "meta": {}}, box_dots=True)
        data.meta["update_ts"] = now.timestamp
        for entry in fetched_data:
            entry = transform_entry(entry)
            if entry:
                must_write_data = True
                data.prices.append(entry)
    # Filter out data older than 24h and write to disk
    if must_write_data:
        log.info("Writing Awattar data to disk.")
        before_24h = now.shift(hours=-24).timestamp
        data.prices = [e for e in data.prices if e.end_timestamp > before_24h]
        write_data(data=data, file_path=file_path)
    # As the last resort return empty data.
    if not data:
        data = Box({"prices": []})
    return data

async def get_headers(config: Box, data: Dict) -> Dict:
    data = Box(data)
    headers = {"Cache-Control": "public, max-age={}"}
    max_age = 0

    now = arrow.utcnow()
    price_points_in_future = 0
    for price_point in data.prices:
        if price_point.start_timestamp > now.timestamp:
            price_points_in_future += 1

    if price_points_in_future < int(config.poll.if_less_than):
        # Runs when the data is fetched at every call and the aWATTar data
        # will probably update soon.
        # In that case the client shall only cache data for up to 5 minutes.
        max_age = 300
    else:
        if (price_points_in_future - int(config.poll.if_less_than)) == 0:
            # Runs when it is currently the hour before the backend
            # will continuously look for new price data.
            # max_age is set so that the client only caches until the backend
            # will start continuous requesting for new price data.
            next_hour_start = now.replace(hour=now.hour+1, minute=0, second=0, microsecond=0)
            difference = next_hour_start - now
            max_age = difference.seconds
        else:
            # Runs on default when server doesn't continuously look for new price data.
            # and it isn't the hour before continouse updating will occur.
            max_age = 900

    headers["Cache-Control"] = headers["Cache-Control"].format(max_age)
    return headers

def main() -> Box:
    """Entry point for the data poller."""
    config = read_config()
    start_logging(config)
    data = get_data(config)
    return data


if __name__ == "__main__":
    main()
