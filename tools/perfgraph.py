#!/usr/bin/python3
# This file is part of the Luau programming language and is licensed under MIT License; see LICENSE.txt for details
#
# Given a profile dump, this tool generates a flame graph based on the stacks listed in the profile
# The result of analysis is a .svg file which can be viewed in a browser
#
# python3 perfgraph.py profile.out > profile.svg

import argparse
import json

import svg

argumentParser = argparse.ArgumentParser(
    description="Generate flamegraph SVG from Luau sampling profiler dumps"
)
argumentParser.add_argument("source_file", type=open)
argumentParser.add_argument(
    "--json",
    dest="useJson",
    action="store_const",
    const=1,
    default=0,
    help="Parse source_file as JSON",
)


class Node(svg.Node):
    def __init__(self):
        svg.Node.__init__(self)
        self.function = ""
        self.source = ""
        self.line = 0
        self.ticks = 0

    def text(self):
        return self.function

    def title(self):
        if self.line > 0:
            return "{}\n{}:{}".format(self.function, self.source, self.line)
        else:
            return self.function

    def details(self, root):
        key = (self.source, self.function, self.line)

        global_percent = 0.0
        if hasattr(root, "globalTotals"):
            total_runtime = root.width
            if total_runtime > 0 and key in root.globalTotals:
                global_percent = (root.globalTotals[key] / total_runtime) * 100.0

        return (
            "Function: {} [{}:{}]\n"
            "({:,} µs, {:.1%}); self: {:,} µs\n"
            "Global self: {:.2f}%"
        ).format(
            self.function,
            self.source,
            self.line,
            self.width,
            self.width / root.width if root.width > 0 else 0,
            self.ticks,
            global_percent,
        )


# ------------------------------------------------------------
# Callstack list format
# ------------------------------------------------------------


def nodeFromCallstackListFile(source_file):
    dump = source_file.readlines()
    root = Node()

    for l in dump:
        ticks, stack = l.strip().split(" ", 1)
        node = root

        for f in reversed(stack.split(";")):
            source, function, line = f.split(",")

            child = node.child(f)
            child.function = function
            child.source = source
            child.line = int(line) if len(line) > 0 else 0

            node = child

        node.ticks += int(ticks)

    return root


# ------------------------------------------------------------
# JSON V2
# ------------------------------------------------------------


def getDuration(nodes, nid):
    node = nodes[nid - 1]
    total = node["TotalDuration"]

    if "NodeIds" in node:
        for cid in node["NodeIds"]:
            total -= nodes[cid - 1]["TotalDuration"]

    return total


def getFunctionKey(fn):
    source = fn["Source"] if "Source" in fn else ""
    name = fn["Name"] if "Name" in fn else ""
    line = str(fn["Line"]) if "Line" in fn else "-1"

    return source + "," + name + "," + line


def recursivelyBuildNodeTree(nodes, functions, parent, fid, nid):
    ninfo = nodes[nid - 1]
    finfo = functions[fid - 1]

    child = parent.child(getFunctionKey(finfo))
    child.source = finfo.get("Source", "")
    child.function = finfo.get("Name", "")
    child.line = int(finfo["Line"]) if finfo.get("Line", 0) > 0 else 0

    child.ticks = getDuration(nodes, nid)

    if "FunctionIds" in ninfo:
        for i in range(len(ninfo["FunctionIds"])):
            recursivelyBuildNodeTree(
                nodes,
                functions,
                child,
                ninfo["FunctionIds"][i],
                ninfo["NodeIds"][i],
            )


def nodeFromJSONV2(dump):
    nodes = dump["Nodes"]
    functions = dump["Functions"]
    categories = dump["Categories"]

    root = Node()

    for category in categories:
        nid = category["NodeId"]
        node = nodes[nid - 1]
        name = category["Name"]

        child = root.child(name)
        child.function = name
        child.ticks = getDuration(nodes, nid)

        if "FunctionIds" in node:
            for i in range(len(node["FunctionIds"])):
                recursivelyBuildNodeTree(
                    nodes,
                    functions,
                    child,
                    node["FunctionIds"][i],
                    node["NodeIds"][i],
                )

    return root


# ------------------------------------------------------------
# JSON V1
# ------------------------------------------------------------


def getDurationV1(obj):
    total = obj["TotalDuration"]

    if "Children" in obj:
        for _, child in obj["Children"].items():
            total -= child["TotalDuration"]

    return total


def nodeFromJSONObject(node, key, obj):
    source, function, line = key.split(",")

    node.function = function
    node.source = source
    node.line = int(line) if len(line) > 0 else 0

    node.ticks = getDurationV1(obj)

    if "Children" in obj:
        for key, child in obj["Children"].items():
            nodeFromJSONObject(node.child(key), key, child)

    return node


def nodeFromJSONV1(dump):
    root = Node()

    if "Children" in dump:
        for key, obj in dump["Children"].items():
            nodeFromJSONObject(root.child(key), key, obj)

    return root


def nodeFromJSONFile(source_file):
    dump = json.load(source_file)

    if dump["Version"] == 2:
        return nodeFromJSONV2(dump)
    elif dump["Version"] == 1:
        return nodeFromJSONV1(dump)

    return Node()


# ------------------------------------------------------------
# Global cumulative self-time aggregation
# ------------------------------------------------------------


def computeGlobalSelfTotals(root):
    totals = {}

    def visit(node):
        key = (node.source, node.function, node.line)

        if key not in totals:
            totals[key] = 0

        totals[key] += node.ticks

        for child in node.children.values():
            visit(child)

    visit(root)
    return totals


def printCumulativeSelfPercent(root):
    import sys

    totals = root.globalTotals
    total_time = root.width

    print("\n=== Cumulative Self Time (% of total) ===", file=sys.stderr)

    for (source, function, line), ticks in sorted(
        totals.items(), key=lambda x: x[1], reverse=True
    )[:5]:
        if ticks <= 0:
            continue

        percent = (ticks / total_time) * 100 if total_time > 0 else 0

        print(
            "{:6.2f}%  {:,} µs  {} [{}:{}]".format(
                percent, ticks, function, source, line
            ),
            file=sys.stderr,
        )


# ------------------------------------------------------------
# Main
# ------------------------------------------------------------

arguments = argumentParser.parse_args()

if arguments.useJson:
    root = nodeFromJSONFile(arguments.source_file)
else:
    root = nodeFromCallstackListFile(arguments.source_file)

# Layout computes inclusive widths
svg.layout(root, lambda n: n.ticks)

# Compute global cumulative self time
root.globalTotals = computeGlobalSelfTotals(root)

# Optional console output section
printCumulativeSelfPercent(root)

# Render SVG
svg.display(root, "Flame Graph", "hot", flip=True)
