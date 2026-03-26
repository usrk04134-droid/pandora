import pytest
from testzilla.plc import models


def test_browse_params():
    # Preparation
    params = {"mode": "children", "type": ["code_blocks", "data_blocks", "tags"], "var": "dummy"}

    # Execution and Verification
    try:
        models.BrowseParams(**params)
    except ValueError as e:
        pytest.fail(f"An exception was raised: {e}")


def test_browse_params_invalid_type():
    # Preparation
    params = {"mode": "children", "type": ["invalid_type"]}

    # Execution and Verification
    with pytest.raises(ValueError) as exc_info:
        models.BrowseParams(**params)

    assert "Input should be 'code_blocks', 'data_blocks' or 'tags'" in str(exc_info.value)


def test_browse_params_invalid_mode():
    # Preparation
    params = {"mode": "invalid_mode"}

    # Execution and Verification
    with pytest.raises(ValueError) as exc_info:
        models.BrowseParams(**params)

    assert "Input should be 'children' or 'var'" in str(exc_info.value)


def test_browse_params_invalid_combination():
    # Preparation
    params = {"mode": "var", "type": None, "var": None}

    # Execution and Verification
    with pytest.raises(ValueError) as exc_info:
        models.BrowseParams(**params)

    assert "'var' is required when 'mode' is 'var'" in str(exc_info.value)


def test_read_params():
    # Preparation
    params = {"mode": "raw", "var": "dummy"}

    # Execution and Verification
    try:
        models.ReadParams(**params)
    except ValueError as e:
        pytest.fail(f"An exception was raised: {e}")


def test_read_params_invalid_mode():
    # Preparation
    params = {"mode": "invalid_mode", "var": "dummy"}

    # Execution and Verification
    with pytest.raises(ValueError) as exc_info:
        models.ReadParams(**params)

    assert "Input should be 'raw' or 'simple'" in str(exc_info.value)


def test_write_params():
    # Preparation
    params = {"mode": "simple", "value": 1.0, "var": "dummy"}

    # Execution and Verification
    try:
        models.WriteParams(**params)
    except ValueError as e:
        pytest.fail(f"An exception was raised: {e}")


def test_write_params_invalid_mode():
    # Preparation
    params = {"mode": "invalid_mode", "value": "dummy", "var": "dummy"}

    # Execution and Verification
    with pytest.raises(ValueError) as exc_info:
        models.WriteParams(**params)

    assert "Input should be 'raw' or 'simple'" in str(exc_info.value)
