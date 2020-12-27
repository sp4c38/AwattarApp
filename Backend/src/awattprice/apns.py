import asyncio
import json
import sqlite3

from fastapi import Request
from loguru import logger as log
from pathlib import Path

from awattprice.config import read_config
from awattprice.token_manager import APNs_Token_Manager
from awattprice.utils import read_data, write_data

async def write_token(request_data, db_manager):
    log.info("Initiated a new background task to store an APNs token.")
    # Write the token to a file to store it.
    apns_token_manager = APNs_Token_Manager(request_data, db_manager)

    await apns_token_manager.acquire_lock()
    need_to_write_data = await apns_token_manager.set_data()
    if need_to_write_data:
        await apns_token_manager.write_to_database()
    await apns_token_manager.release_lock()

    return

async def validate_token(request: Request):
    # Check if backend can successfully get APNs token from request body.
    request_body = await request.body()
    decoded_body = request_body.decode('utf-8')

    try:
        body_json = json.loads(decoded_body)

        request_data = {"token": None, "region_identifier": None, "config": None}
        request_data["token"] = body_json["apnsDeviceToken"]
        request_data["region_identifier"] = body_json["regionIdentifier"]
        request_data["config"] = {"price_below_value_notification": {"active": False, "below_value": float(0)}}

        # Always need to check with an if statment to ensure backwards-compatibility
        # of users using old AWattPrice versions
        if "priceBelowValueNotification" in body_json["notificationConfig"]:
            below_notification = body_json["notificationConfig"]["priceBelowValueNotification"]
            if "active" in below_notification and "belowValue" in below_notification:
                active = below_notification["active"]
                below_value = below_notification["belowValue"]
                # Limit below_value to two decimal places.
                # The app normally should already have rounded this number to two decimal places.
                below_value = round(below_value, 2)
                request_data["config"]["price_below_value_notification"]["active"] = active
                request_data["config"]["price_below_value_notification"]["below_value"] = below_value

        if not request_data["token"] == None and not request_data["config"] == None:
            request_data_valid = True

            if not (type(request_data["token"]) == str):
                request_data_valid = False
            if not (type(request_data["region_identifier"]) == int):
                request_data_valid = False
            if not (type(request_data["config"]["price_below_value_notification"]["active"]) == bool):
                request_data_valid = False
            if not (type(request_data["config"]["price_below_value_notification"]["below_value"]) == float):
                request_data_valid = False

            if request_data_valid:
                log.info("APNs data (sent from a client) is valid.")
                return request_data
            else:
                log.info("APNs data (sent from a client) is NOT valid.")
                return None
    except Exception as exp:
        log.warning("Could NOT decode to a valid json when validating client APNs data.\n"\
                   f"Sent data: {decoded_body}\n"\
                   f"Exception: {exp}")
        return None
