#!/usr/bin/env python3
"""Offline smoke tests for research function-contract parser (no D toolchain)."""
import unittest
from audit_function_contracts import norm, ddox_return, type_parts, signature_parts


class ContractParsingTests(unittest.TestCase):
    def test_plain_return_and_attributes(self):
        sig = "bool tryFromNumber ( const ( uint ) number ) pure nothrow @nogc @safe ;"
        _, attributes = signature_parts(sig)
        self.assertEqual(ddox_return(sig, "UtmZone.tryFromNumber"), "bool")
        self.assertEqual(attributes, {"pure", "nothrow", "@nogc", "@safe"})

    def test_dmd_method_qualifier_and_return(self):
        self.assertEqual(
            type_parts("const pure nothrow @nogc @safe bool(const T x)"),
            ("bool", frozenset({"pure", "nothrow", "@nogc", "@safe"})))

    def test_templated_return_from_ddox(self):
        sig = "Angle !T asAngle ( ) const pure nothrow @nogc @property @safe ;"
        self.assertEqual(ddox_return(sig, "Latitude.asAngle"), "Angle!T")

    def test_opaque_dmd_type_unresolved(self):
        self.assertIsNone(type_parts(""))

    def test_whitespace_normalization(self):
        self.assertEqual(norm("const ( uint )"), norm("const(uint)"))


if __name__ == "__main__":
    unittest.main()
