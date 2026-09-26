/**
 * Error channel for throwing geodesy-d value construction and operations.
 *
 * geodesy-d normally pairs checked `try...` APIs with throwing convenience
 * peers. Checked operations report supported semantic failure with `false`;
 * throwing peers use `GeodesyValueException` for the corresponding invalid
 * input, unsupported domain, or unrepresentable-result conditions.
 *
 * See_Also:
 *     Checked `try...` operations throughout the public `geodesy` API.
 *
 * Authors:
 *     Alexander Bernardi
 *
 * Copyright:
 *     Copyright © 2026 Alexander Bernardi
 *
 * License:
 *     MIT
 *
 * Date:
 *     September 26, 2026
 */
module geodesy.errors;

/**
 * Exception used by throwing convenience APIs when the corresponding checked
 * operation would fail because of invalid input, unsupported domain, or an
 * unrepresentable result.
 *
 * Checked `try...` APIs report the same semantic failures with `false`
 * instead of throwing.
 */
final class GeodesyValueException : Exception
{
    /**
     * Construct an exception with source location metadata.
     *
     * Params:
     *     message = Human-readable failure description.
     *     file = Source file recorded on the exception.
     *     line = Source line recorded on the exception.
     */
    @safe this(string message, string file = __FILE__, size_t line = __LINE__)
    {
        super(message, file, line);
    }
}
