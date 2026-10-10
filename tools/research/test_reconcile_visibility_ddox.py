#!/usr/bin/env python3
import unittest
from reconcile_visibility_ddox import reconcile


class VisibilityDDoxReconciliationTests(unittest.TestCase):
    def test_name_only_classification(self):
        reflected = [
            dict(module="geodesy.angle", name="Angle", protection="public"),
            dict(module="geodesy.angle", name="Internal", protection="private"),
            dict(module="geodesy.angle", name="Unlisted", protection="public"),
            dict(module="geodesy", name="Angle", protection="public"),
            dict(module="geodesy", name="geodesy", protection="public"),
            dict(module="geodesy", name="object", protection="public"),
            dict(module="geodesy.angle", name="object", protection="public"),
        ]
        docs = [dict(module="geodesy.angle", symbol="Angle")]
        actual = {(r["module"], r["name"]): r["status"]
                  for r in reconcile(reflected, docs)}
        self.assertEqual(actual[("geodesy.angle", "Angle")], "documented_name")
        self.assertEqual(actual[("geodesy.angle", "Internal")], "nonpublic_declared")
        self.assertEqual(actual[("geodesy.angle", "Unlisted")],
                         "public_name_requires_review")
        self.assertEqual(actual[("geodesy", "Angle")],
                         "root_member_requires_reexport_review")
        self.assertEqual(actual[("geodesy", "geodesy")], "root_module_self_name")
        self.assertEqual(actual[("geodesy", "object")], "implicit_object_import")
        self.assertEqual(actual[("geodesy.angle", "object")], "implicit_object_import")

    def test_member_pages_are_not_top_level_names(self):
        entries = [dict(module="geodesy.angle", name="Angle", protection="public")]
        docs = [dict(module="geodesy.angle", symbol="Angle.degrees")]
        self.assertEqual(reconcile(entries, docs)[0]["status"],
                         "public_name_requires_review")


if __name__ == "__main__":
    unittest.main()
