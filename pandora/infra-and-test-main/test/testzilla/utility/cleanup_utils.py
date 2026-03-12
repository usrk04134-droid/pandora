"""WebSocket / AdaptioWebHmi cleanup utilities."""

import asyncio

from laserbeak import logger
from testzilla.adaptio_web_hmi.adaptio_web_hmi import AdaptioWebHmi


def cleanup_web_hmi_client(web_hmi: AdaptioWebHmi) -> None:
    """Safely close AdaptioWebHmi client and clean up pending websocket tasks."""
    try:
        web_hmi.close()
        logger.debug("Closed WebHMI client")
    except Exception as e:
        logger.debug(f"Error closing web_hmi: {e}")

    # Cancel any remaining tasks from the websocket (defense-in-depth: the
    # WebSocketClient.close() method already cancels internal tasks, but we
    # repeat the sweep here in case any slipped through).
    try:
        ws_client = getattr(web_hmi, "ws_client", None)
        loop = getattr(ws_client, "loop", None) if ws_client else None
        if loop is None:
            loop = asyncio.get_event_loop()

        if loop and not loop.is_closed() and not loop.is_running():
            pending = [task for task in asyncio.all_tasks(loop) if not task.done()]
            for task in pending:
                task.cancel()
                logger.debug(f"Cancelled pending task: {task.get_name()}")

            # Drain cancellations so websocket cleanup completes before loop closes
            if pending:
                try:
                    loop.run_until_complete(
                        asyncio.gather(*pending, return_exceptions=True)
                    )
                except (asyncio.CancelledError, RuntimeError):
                    pass

            # Run extra ticks so websocket coroutine stacks fully unwind
            # after CancelledError delivery (each nested await needs one tick).
            for _ in range(5):
                try:
                    loop.run_until_complete(asyncio.sleep(0))
                except RuntimeError:
                    break

            # Close the loop if it was created by this sync client so that
            # WebSocketClientSync.__del__ finds an already-closed loop and
            # skips the redundant drain/close cycle.
            loop_created = getattr(ws_client, "_loop_created", False)
            if loop_created and not loop.is_closed():
                loop.close()
                logger.debug("Closed owned event loop in cleanup_web_hmi_client")
    except (RuntimeError, ValueError):
        # No event loop in current thread or loop is closed
        pass
