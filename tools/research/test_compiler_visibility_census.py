#!/usr/bin/env python3
import unittest
from compiler_visibility_census import exported_modules, generated_source, parse_records


class VisibilityCensusTests(unittest.TestCase):
    def test_exported_modules(self):
        text = """
        public import geodesy.angle;
        public import geodesy.projection.utm;
        """
        self.assertEqual(
            exported_modules(text),
            ["geodesy.angle", "geodesy.projection.utm"],
        )

    def test_duplicate_import_rejected(self):
        with self.assertRaises(ValueError):
            exported_modules(
                "public import geodesy.angle;\npublic import geodesy.angle;\n"
            )

    def test_generated_source_uses_compiler_visibility_traits(self):
        source = generated_source(["geodesy.angle"])
        self.assertIn("__traits(allMembers, m0)", source)
        self.assertIn("__traits(getProtection, __traits(getMember, m0, name))", source)
        self.assertIn("__GEODESY_VIS__\\tgeodesy\\t", source)
        self.assertIn("__GEODESY_VIS__\\tgeodesy.angle\\t", source)

    def test_parse_records_deduplicates(self):
        raw = (
            "__GEODESY_VIS__\tgeodesy.angle\tAngle\tpublic\n"
            "__GEODESY_VIS__\tgeodesy.angle\t_internal\tprivate\n"
            "__GEODESY_VIS__\tgeodesy.angle\tAngle\tpublic\n"
        )
        self.assertEqual(
            parse_records(raw),
            [
                {"module": "geodesy.angle", "name": "Angle", "protection": "public"},
                {"module": "geodesy.angle", "name": "_internal", "protection": "private"},
            ],
        )


if __name__ == "__main__":
    unittest.main()
