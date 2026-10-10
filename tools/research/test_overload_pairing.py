#!/usr/bin/env python3
"""Offline regressions for DDox/DMD overload pairing."""
import unittest

from overload_pairing import pair


class PairingTest(unittest.TestCase):
    def test_unique_parameter_tuple_independent_of_declaration_order(self):
        doc = [
            {"module": "geodesy.mock", "symbol": "foo", "overload": "1",
             "signature": "int foo(int x);"},
            {"module": "geodesy.mock", "symbol": "foo", "overload": "2",
             "signature": "int foo(double x);"},
        ]
        dmd = [
            {"module": "geodesy.mock", "symbol": "foo", "kind": "function",
             "parameters": '[{"type":"double","name":"x"}]', "line": "20"},
            {"module": "geodesy.mock", "symbol": "foo", "kind": "function",
             "parameters": '[{"type":"int","name":"x"}]', "line": "10"},
        ]
        rows = pair(doc, dmd)
        self.assertEqual([row["status"] for row in rows],
                         ["unique_parameter_match"] * 2)
        self.assertEqual([row["dmd_source_line"] for row in rows], ["10", "20"])

    def test_duplicate_compiler_candidates_are_not_assumed_unique(self):
        doc = [
            {"module": "geodesy.mock", "symbol": "foo", "overload": str(i),
             "signature": "int foo(int x);"} for i in (1, 2)
        ]
        dmd = [
            {"module": "geodesy.mock", "symbol": "foo", "kind": "function",
             "parameters": '[{"type":"int","name":"x"}]', "line": str(i)}
            for i in (10, 20)
        ]
        rows = pair(doc, dmd)
        self.assertIn("ambiguous_parameter_match",
                      [row["status"] for row in rows])


if __name__ == "__main__":
    unittest.main()
