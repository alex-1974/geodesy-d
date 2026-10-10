#!/usr/bin/env python3
"""Offline contract pairing regression tests."""
import unittest
from audit_paired_overloads import audit


class ContractPairingTests(unittest.TestCase):
    def test_pairing_by_parameters_not_declaration_order(self):
        pages = [
            {"module": "geodesy.test", "symbol": "call", "overload": "1",
             "signature": "bool call(int x) pure nothrow @nogc @safe;"},
            {"module": "geodesy.test", "symbol": "call", "overload": "2",
             "signature": "double call(double x) pure nothrow @nogc @safe;"},
        ]
        dmd = [
            {"module": "geodesy.test", "symbol": "call", "kind": "function",
             "line": "20", "parameters": '[{"type":"double","name":"x"}]',
             "type": "pure nothrow @nogc @safe double(double x)"},
            {"module": "geodesy.test", "symbol": "call", "kind": "function",
             "line": "10", "parameters": '[{"type":"int","name":"x"}]',
             "type": "pure nothrow @nogc @safe bool(int x)"},
        ]
        result = audit(pages, dmd)
        self.assertEqual([x["dmd_line"] for x in result], ["10", "20"])
        for row in result:
            self.assertEqual(row["parameters"], "unique_match")
            self.assertEqual(row["return_type"], "selected_match")
            self.assertEqual(row["selected_attributes"], "selected_match")
            self.assertEqual(row["template_constraints"], "pending")

    def test_opaque_compiler_type_is_not_a_match(self):
        pages = [
            {"module": "geodesy.test", "symbol": "call", "overload": "1",
             "signature": "bool call(int x) @safe;"},
            {"module": "geodesy.test", "symbol": "call", "overload": "2",
             "signature": "bool call(double x) @safe;"},
        ]
        dmd = [
            {"module": "geodesy.test", "symbol": "call", "kind": "function",
             "line": str(line), "parameters": parameters, "type": ""}
            for line, parameters in (
                (10, '[{"type":"int","name":"x"}]'),
                (20, '[{"type":"double","name":"x"}]'),
            )
        ]
        result = audit(pages, dmd)
        self.assertTrue(all(x["parameters"] == "unique_match" for x in result))
        self.assertTrue(all(x["return_type"] == "unresolved" for x in result))


if __name__ == "__main__":
    unittest.main()
