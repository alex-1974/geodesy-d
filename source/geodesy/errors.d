/**
 * Error types used by checked geodesy-d value construction and operations.
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
