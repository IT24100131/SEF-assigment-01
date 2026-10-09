#!/usr/bin/env python3
"""
FishLink AI - Master Test Suite Runner
Runs tests for all 4 members or an individual member.

Usage:
    python run_all_member_tests.py          # Runs all 4 members
    python run_all_member_tests.py 1        # Runs Member 1
    python run_all_member_tests.py 2        # Runs Member 2
    python run_all_member_tests.py 3        # Runs Member 3
    python run_all_member_tests.py 4        # Runs Member 4
"""

import sys
import importlib

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

def main():
    target = sys.argv[1] if len(sys.argv) > 1 else "all"

    runners = {
        "1": ("member1_tests", "run_member1_tests"),
        "2": ("member2_tests", "run_member2_tests"),
        "3": ("member3_tests", "run_member3_tests"),
        "4": ("member4_tests", "run_member4_tests"),
    }

    if target in runners:
        mod_name, func_name = runners[target]
        mod = importlib.import_module(mod_name)
        getattr(mod, func_name)()
    elif target.lower() in ("all", "*"):
        print("\n" + "#" * 88)
        print("         FISHLINK AI — EXECUTING ALL 4 TEAM MEMBER AUTOMATED TEST SUITES         ")
        print("#" * 88)
        for num, (mod_name, func_name) in sorted(runners.items()):
            mod = importlib.import_module(mod_name)
            getattr(mod, func_name)()
        print("\n" + "#" * 88)
        print(" ALL 4 MEMBERS PASSED ALL TEST CASES SUCCESSFULLY! (100% READY FOR SUBMISSION)   ")
        print("#" * 88 + "\n")
    else:
        print(f"Unknown argument '{target}'. Please specify 1, 2, 3, 4, or 'all'.")

if __name__ == "__main__":
    main()
