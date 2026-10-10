#!/usr/bin/env python3
"""Offline grammar tests for intersection call-generation."""
import unittest

from generate_intersection_consumer import parameter_type, parameters, generate


class IntersectionGeneratorTests(unittest.TestCase):
    def test_ref_out_const_and_array_types(self):
        inputs = (
            "const GeodesicIntersectionSolver !T intersector",
            "ref GeodesicIntersectionWorkspace !T workspace",
            "out GeodesicClosestIntersectionResult !T result",
            "GeodesicIntersectionPoint !T [] output",
            "const T referenceOnFirst = cast ( T ) 0",
        )
        self.assertEqual(
            [parameter_type(x) for x in inputs],
            ["GeodesicIntersectionSolver!T", "GeodesicIntersectionWorkspace!T",
             "GeodesicClosestIntersectionResult!T",
             "GeodesicIntersectionPoint!T[]", "T"])

    def test_template_list_extraction(self):
        signature = ("bool tryClosestGeodesicIntersection (T) "
                     "( const Geodesic !T solver , "
                     "out GeodesicClosestIntersectionResult !T result ) "
                     "pure nothrow @safe @nogc if ( isGeodesyScalar !T );")
        self.assertEqual(
            len(parameters(signature, "tryClosestGeodesicIntersection")), 2)

    def test_incomplete_census_rejected(self):
        with self.assertRaises(ValueError):
            generate([])


if __name__ == "__main__":
    unittest.main()
