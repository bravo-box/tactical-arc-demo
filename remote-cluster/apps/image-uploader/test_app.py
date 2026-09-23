from __future__ import annotations

import unittest

from app import BreakerState, ConnectivityCircuitBreaker


class ConnectivityCircuitBreakerTests(unittest.TestCase):
    def test_opens_after_five_failures(self) -> None:
        breaker = ConnectivityCircuitBreaker()
        for second in range(4):
            breaker.record(False, second)
            self.assertEqual(breaker.state, BreakerState.CLOSED)

        breaker.record(False, 4)

        self.assertEqual(breaker.state, BreakerState.OPEN)
        self.assertFalse(breaker.should_probe(63))

    def test_half_open_after_one_minute_and_closes_on_success(self) -> None:
        breaker = ConnectivityCircuitBreaker()
        for second in range(5):
            breaker.record(False, second)

        self.assertTrue(breaker.should_probe(64))
        self.assertEqual(breaker.state, BreakerState.HALF_OPEN)
        self.assertEqual(breaker.probe_interval, 1)

        breaker.record(True, 65)

        self.assertEqual(breaker.state, BreakerState.CLOSED)
        self.assertEqual(breaker.probe_interval, 5)
        self.assertEqual(breaker.failures, 0)

    def test_half_open_failure_keeps_probing_every_second(self) -> None:
        breaker = ConnectivityCircuitBreaker(state=BreakerState.HALF_OPEN, failures=5)
        breaker.record(False, 70)

        self.assertEqual(breaker.state, BreakerState.HALF_OPEN)
        self.assertEqual(breaker.probe_interval, 1)


if __name__ == "__main__":
    unittest.main()
