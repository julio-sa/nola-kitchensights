import asyncio
import inspect
import pytest


@pytest.fixture
def event_loop():
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest.hookimpl(tryfirst=True)
def pytest_pyfunc_call(pyfuncitem):
    """Executa testes assíncronos marcados com @pytest.mark.asyncio."""
    if inspect.iscoroutinefunction(pyfuncitem.obj):
        loop = pyfuncitem.funcargs.get("event_loop")
        if loop is None:
            loop = asyncio.new_event_loop()
            pyfuncitem.funcargs["event_loop"] = loop
        call_args = {
            name: value
            for name, value in pyfuncitem.funcargs.items()
            if name != "event_loop"
        }
        loop.run_until_complete(pyfuncitem.obj(**call_args))
        return True
    return None
