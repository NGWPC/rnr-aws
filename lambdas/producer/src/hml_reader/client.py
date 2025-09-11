from typing import Any, Dict, Optional

import httpx


async def async_get(
    endpoint: str, params: Optional[Dict[str, Any]] = None, headers: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """An asynchronous GET request using httpx.

    Parameters
    ----------
    endpoint : str
        The URL we're hitting.

    params : Optional[Dict[str, Any]]
        The parameters passed to the API endpoint.

    headers: Optional[Dict[str, Any]]
        The headers belonging to the request

    Returns
    -------
    Dict[str, Any]
        The JSON response from the API.
    """
    async with httpx.AsyncClient(timeout=30) as client:
        response = await client.get(endpoint, params=params, headers=headers)
        response.raise_for_status()
        return response.json()


def get(
    endpoint: str, params: Optional[Dict[str, Any]] = None, headers: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """A synchronous GET request using httpx.

    Parameters
    ----------
    endpoint : str
        The URL we're hitting.

    params : Optional[Dict[str, Any]]
        The parameters passed to the API endpoint.

    headers: Optional[Dict[str, Any]]
        The headers belonging to the request

    Returns
    -------
    Dict[str, Any]
        The JSON response from the API.
    """
    with httpx.Client() as client:
        try:
            response = client.get(endpoint, params=params, headers=headers)
            response.raise_for_status()
            return response.json()
        except httpx.HTTPStatusError as e:
            raise e("Status Error")
        except httpx.RequestError as e:
            raise e("Request Error")
