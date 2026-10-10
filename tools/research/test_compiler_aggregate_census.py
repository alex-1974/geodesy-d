#!/usr/bin/env python3
import unittest
from compiler_aggregate_census import generate, parse


class AggregateCensusTests(unittest.TestCase):
    def test_generated_reflection_checks_protection(self):
        source = generate(["geodesy.angle"])
        self.assertIn("import m0 = geodesy.angle;", source)
        self.assertIn("__traits(allMembers, T)", source)
        self.assertIn("__traits(getProtection, __traits(getMember, T, memberName))",
                      source)
        self.assertIn("__GEODESY_AGG__\\tgeodesy.angle\\t", source)

    def test_parse_records(self):
        raw = ("__GEODESY_AGG__\tgeodesy.angle\tAngle\tradians\tpublic\n"
               "__GEODESY_AGG__\tgeodesy.angle\tAngle\tsecret\tprivate\n")
        self.assertEqual(parse(raw), [
            dict(module="geodesy.angle", type="Angle", member="radians",
                 protection="public"),
            dict(module="geodesy.angle", type="Angle", member="secret",
                 protection="private"),
        ])


if __name__ == "__main__":
    unittest.main()
