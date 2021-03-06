"""Contains default values and models."""
from decimal import Decimal
from enum import auto
from enum import Enum
from typing import Optional

from box import Box

from awattprice import defaults


class Region(str, Enum):
    """Identify a region (country)."""

    DE = "DE"
    AT = "AT"

    @property
    def tax(self) -> Optional[Decimal]:
        tax = REGION_TAXES[self]
        return tax

# Multipliers to get the taxed price.
REGION_TAXES = {Region.DE: Decimal("1.19"), Region.AT: None}

AWATTPRICE_SERVICE_NAME = "awattprice"
APP_BUNDLE_ID = "me.space8.AWAttPrice"

DEFAULT_CONFIG = """\
[general]
debug = on

[awattar.de]
url = https://api.awattar.de/v1/marketdata/

[awattar.at]
url = https://api.awattar.at/v1/marketdata/

[paths]
log_dir = ~/awattprice/logs/
data_dir = ~/awattprice/data/
apns_dir = ~/awattprice/apns/

[apns]
team_id =
key_id =
"""

ORM_TABLE_NAMES = Box(
    {
        "token_table": "token",
        "price_below_table": "price_below_notification",
    }
)

SEC_TO_MILLISEC = 1000  # to convert multiply by this factor
EURMWH_TO_CENTWKWH = Decimal("0.001") * Decimal("100")

# Timeout in seconds when requesting from aWATTar.
AWATTAR_TIMEOUT = 10.0
# After polling the API wait x seconds before requesting again.
AWATTAR_COOLDOWN_INTERVAL = 60
# Attempt to update aWATTar prices if its past this hour of the day.
# Always will update at x hour regardless of summer and winter times.
AWATTAR_UPDATE_HOUR = 13

DATABASE_FILE_NAME = "database.sqlite3"  # End with '.sqlite3'


AWATTAR_API_PRICE_DATA_SCHEMA = {
    "type": "object",
    "properties": {
        "object": {"type": "string", "pattern": "^list$"},
        "data": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "start_timestamp": {"type": "integer"},
                    "end_timestamp": {"type": "integer"},
                    "marketprice": {"type": "number"},
                    "unit": {"type": "string", "pattern": "^Eur/MWh$"},
                },
                "required": ["start_timestamp", "end_timestamp", "marketprice", "unit"],
                "minItems": 1,
            },
        },
        "url": {"type": "string", "pattern": "^/at/v1/marketdata/|/de/v1/marketdata/$"},
    },
    "required": ["data", "url"],
}
PRICE_DATA_FILE_NAME = "awattar-data-{}.pickle"  # formatted with lowercase region name
# Name of the subdir in which to store cached price data.
# This subdir is relative to the data dir specified in the config file.
PRICE_DATA_SUBDIR_NAME = "price_data"
# Timeout in seconds to wait when needing the refresh price data lock to be unlocked.
PRICE_DATA_REFRESH_LOCK_TIMEOUT = AWATTAR_TIMEOUT + 2.0
# Name of file which stores the timestamp when prices were updated last.
PRICE_DATA_UPDATE_TS_FILE_NAME = "update-ts-{}.info"  # formatted with lowercase region name
# Decimal places to round cent/kwh prices to.
PRICE_CENTKWH_ROUNDING_PLACES = 2


class TaskType(Enum):
    """Different types of tasks which can be sent by the client to change their notification config."""

    ADD_TOKEN = auto()
    SUBSCRIBE_DESUBSCRIBE = auto()
    UPDATE = auto()


class NotificationType(Enum):
    """Different notification types."""

    PRICE_BELOW = auto()


class UpdateSubject(Enum):
    """Different subjects for which to perform updates."""

    GENERAL = auto()
    PRICE_BELOW = auto()


NOTIFICATION_TASKS_BASE_SCHEMA = {
    "type": "object",
    "properties": {
        "token": {"type": "string", "minLength": 1},
        "tasks": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "type": {"enum": [element.name.lower() for element in TaskType]},
                    "payload": {"type": "object"},
                },
                "required": ["type", "payload"],
                "additionalProperties": False,
            },
            "minItems": 1,
        },
    },
    "required": ["token", "tasks"],
    "additionalProperties": False,
}

region_enum_names = [element.name for element in defaults.Region]

NOTIFICATION_TASK_ADD_TOKEN_SCHEMA = {
    "type": "object",
    "properties": {"region": {"enum": region_enum_names}, "tax": {"type": "boolean"}},
    "required": ["region", "tax"],
    "additionalProperties": False,
}

NOTIFICATION_TASK_SUB_DESUB_SCHEMA = {
    "type": "object",
    "properties": {
        "notification_type": {"enum": [element.name.lower() for element in NotificationType]},
        "sub_else_desub": {"type": "boolean"},
        "notification_info": {"type": "object"},
    },
    "required": ["sub_else_desub", "notification_type", "notification_info"],
    "additionalProperties": False,
}

NOTIFICATION_TASK_PRICE_BELOW_SUB_DESUB_SCHEMA = {
    "type": "object",
    "properties": {"below_value": {"type": "number"}},
    "required": ["below_value"],
    "additionalProperties": False,
}

NOTIFICATION_TASK_UPDATE_SCHEMA = {
    "type": "object",
    "properties": {
        "subject": {"enum": [element.name.lower() for element in UpdateSubject]},
        "updated_data": {"type": "object"},
    },
    "required": ["subject", "updated_data"],
    "additionalProperties": False,
}

# Make sure that the data updater function understands and is able to process all properties specified here.
NOTIFICATION_TASK_UPDATE_GENERAL_SCHEMA = {
    "type": "object",
    "properties": {
        "region": {"enum": region_enum_names},
        "tax": {"type": "boolean"},
    },
    "minProperties": 1,
    "additionalProperties": False,
}

NOTIFICATION_TASK_UPDATE_PRICE_BELOW_SCHEMA = {
    "type": "object",
    "properties": {"below_value": {"type": "number"}},
    "minProperties": 1,
    "additionalProperties": False,
}
