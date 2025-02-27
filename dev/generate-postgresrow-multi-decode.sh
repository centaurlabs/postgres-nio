#!/bin/bash

set -eu

here="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function genWithContextParameter() {
    how_many=$1

    if [[ $how_many -ne 1 ]] ; then
        echo ""
    fi

    echo "    @inlinable"
    echo "    @_alwaysEmitIntoClient"
    echo -n "    public func decode<T0: PostgresDecodable"
    for ((n = 1; n<$how_many; n +=1)); do
        echo -n ", T$(($n)): PostgresDecodable"
    done

    echo -n ", JSONDecoder: PostgresJSONDecoder>(_: (T0"
    for ((n = 1; n<$how_many; n +=1)); do
        echo -n ", T$(($n))"
    done
    echo -n ").Type, context: PostgresDecodingContext<JSONDecoder>, file: String = #file, line: Int = #line) throws"

    echo -n " -> (T0"
    for ((n = 1; n<$how_many; n +=1)); do
        echo -n ", T$(($n))"
    done
    echo ") {"
    echo "        precondition(self.columns.count >= $how_many)"
    #echo "        var columnIndex = 0"
    if [[ $how_many -eq 1 ]] ; then
        echo "        let columnIndex = 0"
        echo "        var cellIterator = self.data.makeIterator()"
        echo "        var cellData = cellIterator.next().unsafelyUnwrapped"
        echo "        var columnIterator = self.columns.makeIterator()"
        echo "        let column = columnIterator.next().unsafelyUnwrapped"
        echo "        let swiftTargetType: Any.Type = T0.self"
    else
        echo "        var columnIndex = 0"
        echo "        var cellIterator = self.data.makeIterator()"
        echo "        var cellData = cellIterator.next().unsafelyUnwrapped"
        echo "        var columnIterator = self.columns.makeIterator()"
        echo "        var column = columnIterator.next().unsafelyUnwrapped"
        echo "        var swiftTargetType: Any.Type = T0.self"
    fi

    echo
    echo "        do {"
    echo "            let r0 = try T0._decodeRaw(from: &cellData, type: column.dataType, format: column.format, context: context)"
    echo
    for ((n = 1; n<$how_many; n +=1)); do
        echo "            columnIndex = $n"
        echo "            cellData = cellIterator.next().unsafelyUnwrapped"
        echo "            column = columnIterator.next().unsafelyUnwrapped"
        echo "            swiftTargetType = T$n.self"
        echo "            let r$n = try T$n._decodeRaw(from: &cellData, type: column.dataType, format: column.format, context: context)"
        echo
    done

    echo -n "            return (r0"
    for ((n = 1; n<$how_many; n +=1)); do
        echo -n ", r$(($n))"
    done
    echo ")"
    echo "        } catch let code as PostgresDecodingError.Code {"
    echo "            throw PostgresDecodingError("
    echo "                code: code,"
    echo "                columnName: column.name,"
    echo "                columnIndex: columnIndex,"
    echo "                targetType: swiftTargetType,"
    echo "                postgresType: column.dataType,"
    echo "                postgresFormat: column.format,"
    echo "                postgresData: cellData,"
    echo "                file: file,"
    echo "                line: line"
    echo "            )"
    echo "        }"
    echo "    }"
}

function genWithoutContextParameter() {
    how_many=$1

    echo ""

    echo "    @inlinable"
    echo "    @_alwaysEmitIntoClient"
    echo -n "    public func decode<T0: PostgresDecodable"
    for ((n = 1; n<$how_many; n +=1)); do
        echo -n ", T$(($n)): PostgresDecodable"
    done

    echo -n ">(_: (T0"
    for ((n = 1; n<$how_many; n +=1)); do
        echo -n ", T$(($n))"
    done
    echo -n ").Type, file: String = #file, line: Int = #line) throws"

    echo -n " -> (T0"
    for ((n = 1; n<$how_many; n +=1)); do
        echo -n ", T$(($n))"
    done
    echo ") {"
    echo -n "        try self.decode("
    if [[ $how_many -eq 1 ]] ; then
        echo -n "T0.self"
    else
        echo -n "(T0"
        for ((n = 1; n<$how_many; n +=1)); do
            echo -n ", T$(($n))"
        done
        echo -n ").self"
    fi
    echo ", context: .default, file: file, line: line)"
    echo "    }"
}

grep -q "ByteBuffer" "${BASH_SOURCE[0]}" || {
    echo >&2 "ERROR: ${BASH_SOURCE[0]}: file or directory not found (this should be this script)"
    exit 1
}

{
cat <<"EOF"
/// NOTE: THIS FILE IS AUTO-GENERATED BY dev/generate-postgresrow-multi-decode.sh
EOF
echo

echo "extension PostgresRow {"

# note:
# - widening the inverval below (eg. going from {1..15} to {1..25}) is Semver minor
# - narrowing the interval below is SemVer _MAJOR_!
for n in {1..15}; do
    genWithContextParameter "$n"
    genWithoutContextParameter "$n"
done
echo "}"
} > "$here/../Sources/PostgresNIO/New/PostgresRow-multi-decode.swift"
