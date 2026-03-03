#!/usr/bin/env python3
"""
OpenSpec tasks.md to features.json Converter

This script converts OpenSpec tasks.md files into iFlow CLI features.json format,
enabling seamless integration between spec-driven development and agent tracking.

Features:
- Preserves `passes` state in a separate file (.agent/features-state.json)
- Only keeps unpassed features in features.json
- Uses unique ID prefixes per change (e.g., TANK-SETUP-1, AUTH-SETUP-1)
- Merges with existing features by default

Usage:
    ./openspec-features.py [--input INPUT] [--output OUTPUT]
    
Options:
    --input   Input tasks.md file or directory (default: openspec/changes/*/tasks.md)
    --output  Output features.json file (default: .agent/features.json)
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Set


# State file for preserving passes status
STATE_FILE = ".agent/features-state.json"


class TaskParser:
    """Parse tasks.md files into structured data."""
    
    # Regex patterns for parsing
    TASK_PATTERN = re.compile(
        r'-\s*\[(?P<checked>\s|x)\]\s*\*\*(?P<id>[A-Z0-9-]+)\*\*:\s*(?P<description>.+)'
    )
    PRIORITY_PATTERN = re.compile(r'Priority:\s*(critical|high|medium|low)', re.IGNORECASE)
    VERIFICATION_PATTERN = re.compile(r'Verification:\s*(.+?)(?=\n\s*-|\n\s*$|\n\s*Depends|\n\s*Notes|$)', re.DOTALL)
    DEPENDS_PATTERN = re.compile(r'Depends on:\s*(.+)')
    NOTES_PATTERN = re.compile(r'Notes:\s*(.+)')
    CATEGORY_PATTERN = re.compile(r'##\s*Category:\s*(.+)', re.IGNORECASE)
    SECTION_PATTERN = re.compile(r'^##\s+\d+\.\s*(.+)$', re.MULTILINE)
    
    def parse_file(self, filepath: str, prefix: str = "") -> Dict:
        """Parse a tasks.md file and return structured data."""
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        return self.parse_content(content, filepath, prefix)
    
    def parse_content(self, content: str, source: str = "unknown", prefix: str = "") -> Dict:
        """Parse tasks.md content and return structured data."""
        result = {
            "source": source,
            "change_name": self._extract_change_name(content),
            "change_prefix": prefix,
            "categories": [],
            "tasks": []
        }
        
        # Split by section headers (## 1. Section Name)
        sections = self.SECTION_PATTERN.split(content)
        
        if len(sections) > 1:
            # First section is the header/intro
            intro = sections[0]
            # Remaining sections alternate between section name and content
            for i in range(1, len(sections), 2):
                if i + 1 < len(sections):
                    section_name = sections[i].strip()
                    section_content = sections[i + 1]
                    tasks = self._parse_tasks(section_content, section_name, prefix)
                    result["categories"].append({
                        "name": section_name,
                        "tasks": tasks
                    })
                    result["tasks"].extend(tasks)
        else:
            # Try old category format
            cat_sections = self.CATEGORY_PATTERN.split(content)
            if len(cat_sections) > 1:
                intro = cat_sections[0]
                for i in range(1, len(cat_sections), 2):
                    if i + 1 < len(cat_sections):
                        category_name = cat_sections[i].strip()
                        category_content = cat_sections[i + 1]
                        tasks = self._parse_tasks(category_content, category_name, prefix)
                        result["categories"].append({
                            "name": category_name,
                            "tasks": tasks
                        })
                        result["tasks"].extend(tasks)
            else:
                # No section headers, parse all tasks
                tasks = self._parse_tasks(content, "General", prefix)
                result["categories"].append({
                    "name": "General",
                    "tasks": tasks
                })
                result["tasks"].extend(tasks)
        
        return result
    
    def _extract_change_name(self, content: str) -> str:
        """Extract the change name from the header."""
        match = re.search(r'#\s*(?:Implementation\s+)?Tasks:\s*(.+)', content)
        if match:
            return match.group(1).strip()
        return "Unknown Change"
    
    def _parse_tasks(self, content: str, category: str, prefix: str = "") -> List[Dict]:
        """Parse individual tasks from content."""
        tasks = []
        
        for match in self.TASK_PATTERN.finditer(content):
            task_id = match.group('id').strip()
            description = match.group('description').strip()
            checked = match.group('checked').strip().lower() == 'x'
            
            # Add prefix to task ID if provided and not already prefixed
            if prefix and not task_id.startswith(prefix):
                prefixed_id = f"{prefix}-{task_id}"
            else:
                prefixed_id = task_id
            
            # Get the rest of the task block (everything until next task or end)
            task_block = self._get_task_block(content, match.end())
            
            # Extract metadata
            priority = self._extract_priority(task_block)
            verification = self._extract_verification(task_block)
            depends_on = self._extract_depends_on(task_block, prefix)
            notes = self._extract_notes(task_block)
            
            task = {
                "id": prefixed_id,
                "original_id": task_id,
                "category": category.lower().replace(' ', '-'),
                "description": description,
                "priority": priority,
                "steps": verification,
                "passes": checked,
                "depends_on": depends_on,
                "notes": notes
            }
            
            tasks.append(task)
        
        return tasks
    
    def _get_task_block(self, content: str, start_pos: int) -> str:
        """Get the task block (metadata) for a task."""
        # Find the next task or end of section
        next_task = self.TASK_PATTERN.search(content, start_pos)
        next_section = self.SECTION_PATTERN.search(content, start_pos)
        next_category = self.CATEGORY_PATTERN.search(content, start_pos)
        
        end_pos = len(content)
        if next_task:
            end_pos = min(end_pos, next_task.start())
        if next_section:
            end_pos = min(end_pos, next_section.start())
        if next_category:
            end_pos = min(end_pos, next_category.start())
        
        return content[start_pos:end_pos]
    
    def _extract_priority(self, block: str) -> str:
        """Extract priority from task block."""
        match = self.PRIORITY_PATTERN.search(block)
        return match.group(1).lower() if match else "medium"
    
    def _extract_verification(self, block: str) -> List[str]:
        """Extract verification steps from task block."""
        match = self.VERIFICATION_PATTERN.search(block)
        if not match:
            return []
        
        verification_text = match.group(1).strip()
        
        # Parse checkbox-style verification steps
        steps = []
        for line in verification_text.split('\n'):
            line = line.strip()
            # Handle checkbox format: - [ ] step
            checkbox_match = re.match(r'-\s*\[\s*\]\s*(.+)', line)
            if checkbox_match:
                steps.append(checkbox_match.group(1).strip())
            # Handle plain text verification
            elif line and not line.startswith('Priority') and not line.startswith('Depends') and not line.startswith('Notes'):
                # Skip if it's just metadata
                if not re.match(r'^[A-Za-z]+:', line):
                    steps.append(line)
        
        # If no steps found, treat the whole verification as one step
        if not steps and verification_text:
            # Remove metadata lines
            clean_text = verification_text
            for pattern in [self.PRIORITY_PATTERN, self.DEPENDS_PATTERN, self.NOTES_PATTERN]:
                clean_text = pattern.sub('', clean_text)
            clean_text = clean_text.strip()
            if clean_text:
                steps.append(clean_text)
        
        return steps
    
    def _extract_depends_on(self, block: str, prefix: str = "") -> Optional[str]:
        """Extract dependency from task block, adding prefix if needed."""
        match = self.DEPENDS_PATTERN.search(block)
        if not match:
            return None
        
        deps = match.group(1).strip()
        
        # Add prefix to dependencies if needed
        if prefix:
            # Split by comma, add prefix to each, rejoin
            dep_list = [d.strip() for d in deps.split(',')]
            prefixed_deps = []
            for dep in dep_list:
                if not dep.startswith(prefix):
                    prefixed_deps.append(f"{prefix}-{dep}")
                else:
                    prefixed_deps.append(dep)
            return ', '.join(prefixed_deps)
        
        return deps
    
    def _extract_notes(self, block: str) -> str:
        """Extract notes from task block."""
        match = self.NOTES_PATTERN.search(block)
        return match.group(1).strip() if match else ""


class StateManager:
    """Manage persistent state for feature passes status."""
    
    def __init__(self, state_file: str = STATE_FILE):
        self.state_file = state_file
        self.state = self._load_state()
    
    def _load_state(self) -> Dict:
        """Load state from file."""
        if os.path.exists(self.state_file):
            try:
                with open(self.state_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except (json.JSONDecodeError, IOError):
                pass
        return {"passed_features": {}, "metadata": {}}
    
    def _save_state(self):
        """Save state to file."""
        os.makedirs(os.path.dirname(self.state_file), exist_ok=True)
        with open(self.state_file, 'w', encoding='utf-8') as f:
            json.dump(self.state, f, indent=2, ensure_ascii=False)
    
    def mark_passed(self, feature_id: str, passed: bool = True):
        """Mark a feature as passed or not."""
        if passed:
            self.state["passed_features"][feature_id] = {
                "passed_at": datetime.now().isoformat(),
                "passed": True
            }
        elif feature_id in self.state["passed_features"]:
            del self.state["passed_features"][feature_id]
        self._save_state()
    
    def is_passed(self, feature_id: str) -> bool:
        """Check if a feature is marked as passed."""
        return self.state.get("passed_features", {}).get(feature_id, {}).get("passed", False)
    
    def get_all_passed(self) -> Set[str]:
        """Get all passed feature IDs."""
        return {fid for fid, data in self.state.get("passed_features", {}).items() if data.get("passed")}
    
    def sync_from_features(self, features: List[Dict]):
        """Sync state from features list (import existing passes)."""
        for feature in features:
            if feature.get("passes"):
                self.mark_passed(feature["id"])
    
    def get_passed_features_data(self) -> Dict:
        """Get all passed features with their metadata."""
        return self.state.get("passed_features", {})


class FeaturesConverter:
    """Convert parsed tasks to features.json format."""
    
    def __init__(self, project_name: str = "Long-Running Agent Environment", state_manager: StateManager = None):
        self.project_name = project_name
        self.state_manager = state_manager or StateManager()
    
    def convert(self, parsed_data: Dict) -> Dict:
        """Convert parsed data to features.json format (only unpassed features)."""
        features = []
        passed_ids = self.state_manager.get_all_passed()
        
        for task in parsed_data["tasks"]:
            feature_id = task["id"]
            
            # Skip passed features - they go to state file, not features.json
            if feature_id in passed_ids:
                continue
            
            feature = {
                "id": feature_id,
                "category": task["category"],
                "description": task["description"],
                "priority": task["priority"],
                "steps": task["steps"] if task["steps"] else [f"Verify: {task['description']}"],
                "passes": False,  # Always False in features.json (passed ones are in state file)
                "status": "pending",
                "claimed_by": None,
                "claimed_at": None,
                "branch": None,
                "notes": task["notes"]
            }
            
            if task.get("depends_on"):
                feature["depends_on"] = task["depends_on"]
                feature["waiting_for"] = task["depends_on"] if isinstance(task["depends_on"], list) else task["depends_on"].split(", ")
            
            features.append(feature)
        
        # Sort by priority
        priority_order = {"critical": 0, "high": 1, "medium": 2, "low": 3}
        features.sort(key=lambda x: priority_order.get(x["priority"], 2))
        
        total_tasks = len(parsed_data["tasks"])
        passed_count = len(passed_ids & {t["id"] for t in parsed_data["tasks"]})
        
        result = {
            "project_name": self.project_name,
            "description": f"Generated from OpenSpec: {parsed_data['change_name']}",
            "version": "1.0.0",
            "features": features,
            "metadata": {
                "created_at": datetime.now().strftime("%Y-%m-%d"),
                "last_updated": datetime.now().strftime("%Y-%m-%d"),
                "source": parsed_data["source"],
                "change_prefix": parsed_data.get("change_prefix", ""),
                "total_features": total_tasks,
                "passed_features": passed_count,
                "pending_features": len(features),
                "completion_percentage": round(passed_count / total_tasks * 100, 1) if total_tasks > 0 else 0
            }
        }
        
        return result
    
    def merge_all(self, all_parsed: List[Dict], existing: Optional[Dict] = None) -> Dict:
        """Merge all parsed data with existing features."""
        # Sync existing passes to state manager
        if existing and existing.get("features"):
            # First, import any passes from existing features
            for f in existing["features"]:
                if f.get("passes"):
                    self.state_manager.mark_passed(f["id"])
        
        # Collect all tasks from all parsed data
        all_tasks = []
        sources = []
        prefixes = []
        
        for parsed in all_parsed:
            all_tasks.extend(parsed["tasks"])
            sources.append(parsed["source"])
            if parsed.get("change_prefix"):
                prefixes.append(parsed["change_prefix"])
        
        # Filter out passed tasks
        passed_ids = self.state_manager.get_all_passed()
        pending_tasks = [t for t in all_tasks if t["id"] not in passed_ids]
        
        # Build features
        features = []
        for task in pending_tasks:
            feature = {
                "id": task["id"],
                "category": task["category"],
                "description": task["description"],
                "priority": task["priority"],
                "steps": task["steps"] if task["steps"] else [f"Verify: {task['description']}"],
                "passes": False,
                "status": "pending",  # pending/claimed/active/completed/waiting/failed
                "claimed_by": None,
                "claimed_at": None,
                "branch": None,
                "notes": task["notes"]
            }
            if task.get("depends_on"):
                feature["depends_on"] = task["depends_on"]
                feature["waiting_for"] = task["depends_on"] if isinstance(task["depends_on"], list) else task["depends_on"].split(", ")
            features.append(feature)
        
        # Sort by priority
        priority_order = {"critical": 0, "high": 1, "medium": 2, "low": 3}
        features.sort(key=lambda x: priority_order.get(x["priority"], 2))
        
        passed_count = len(passed_ids & {t["id"] for t in all_tasks})
        total = len(all_tasks)
        
        return {
            "project_name": existing.get("project_name", self.project_name) if existing else self.project_name,
            "description": existing.get("description", self.project_name) if existing else self.project_name,
            "version": existing.get("version", "1.0.0") if existing else "1.0.0",
            "features": features,
            "metadata": {
                "created_at": existing.get("metadata", {}).get("created_at", datetime.now().strftime("%Y-%m-%d")) if existing else datetime.now().strftime("%Y-%m-%d"),
                "last_updated": datetime.now().strftime("%Y-%m-%d"),
                "source": "; ".join(sources),
                "total_features": total,
                "passed_features": passed_count,
                "pending_features": len(features),
                "completion_percentage": round(passed_count / total * 100, 1) if total > 0 else 0
            }
        }


def extract_prefix_from_change(change_dir: str) -> str:
    """Extract a prefix from the change directory name."""
    dir_name = os.path.basename(change_dir)
    # Convert kebab-case to uppercase prefix
    # e.g., "tank-battle-game" -> "TANK", "add-user-auth" -> "AUTH"
    parts = dir_name.split('-')
    
    # Common abbreviations
    abbreviations = {
        'tank': 'TANK',
        'auth': 'AUTH',
        'user': 'USER',
        'api': 'API',
        'ui': 'UI',
        'game': 'GAME',
        'balance': 'BALANCE',
        'add': 'ADD',
        'setup': 'SETUP',
        'config': 'CFG',
        'test': 'TEST'
    }
    
    # Use first meaningful part
    for part in parts:
        if part.lower() in abbreviations:
            return abbreviations[part.lower()]
        if len(part) >= 3:
            return part.upper()[:4]
    
    # Fallback to first 4 chars of directory name
    return dir_name.upper()[:4] if len(dir_name) >= 4 else dir_name.upper()


def find_tasks_files(base_dir: str) -> List[tuple]:
    """Find all tasks.md files in openspec/changes/*/tasks.md
    Returns list of (filepath, prefix) tuples.
    """
    changes_dir = Path(base_dir) / "openspec" / "changes"
    if not changes_dir.exists():
        return []
    
    tasks_files = []
    for change_dir in changes_dir.iterdir():
        if change_dir.is_dir():
            tasks_file = change_dir / "tasks.md"
            if tasks_file.exists():
                prefix = extract_prefix_from_change(str(change_dir))
                tasks_files.append((str(tasks_file), prefix))
    
    return tasks_files


def main():
    parser = argparse.ArgumentParser(
        description="Convert OpenSpec tasks.md to features.json"
    )
    parser.add_argument(
        "--input", "-i",
        help="Input tasks.md file or directory (default: auto-detect from openspec/changes/*/tasks.md)"
    )
    parser.add_argument(
        "--output", "-o",
        default=".agent/features.json",
        help="Output features.json file (default: .agent/features.json)"
    )
    parser.add_argument(
        "--project-name",
        default="Long-Running Agent Environment",
        help="Project name for features.json"
    )
    parser.add_argument(
        "--state-file",
        default=STATE_FILE,
        help="State file for passed features (default: .agent/features-state.json)"
    )
    
    args = parser.parse_args()
    
    # Initialize state manager
    state_manager = StateManager(args.state_file)
    
    # Find input files
    if args.input:
        if os.path.isdir(args.input):
            tasks_files = find_tasks_files(args.input)
        else:
            # Single file, extract prefix from parent directory
            parent_dir = os.path.basename(os.path.dirname(args.input))
            prefix = extract_prefix_from_change(os.path.dirname(args.input))
            tasks_files = [(args.input, prefix)]
    else:
        tasks_files = find_tasks_files(".")
    
    if not tasks_files:
        print("No tasks.md files found. Please run OpenSpec proposal first.")
        print("\nUsage:")
        print("  /opsx:propose \"your feature description\"")
        print("  Then run this script again.")
        sys.exit(1)
    
    print(f"🔄 Converting OpenSpec tasks to features.json...")
    print(f"\nFound {len(tasks_files)} tasks.md file(s):")
    for filepath, prefix in tasks_files:
        print(f"  - {filepath} (prefix: {prefix})")
    
    # Parse all tasks files
    all_parsed = []
    task_parser = TaskParser()
    
    for tasks_file, prefix in tasks_files:
        print(f"\nParsing: {tasks_file}")
        parsed = task_parser.parse_file(tasks_file, prefix)
        all_parsed.append(parsed)
        print(f"  Found {len(parsed['tasks'])} tasks (prefixed: {prefix})")
    
    # Load existing features to preserve state
    existing_features = None
    if os.path.exists(args.output):
        print(f"\n📖 Loading existing: {args.output}")
        with open(args.output, 'r', encoding='utf-8') as f:
            existing_features = json.load(f)
        
        # Sync existing passes to state manager
        passed_count = sum(1 for f in existing_features.get("features", []) if f.get("passes"))
        if passed_count > 0:
            print(f"  Found {passed_count} passed features to preserve")
    
    # Convert to features.json format
    converter = FeaturesConverter(args.project_name, state_manager)
    features_json = converter.merge_all(all_parsed, existing_features)
    
    # Write output
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(features_json, f, indent=2, ensure_ascii=False)
    
    # Summary
    meta = features_json['metadata']
    print(f"\n✅ Generated: {args.output}")
    print(f"   Total features: {meta['total_features']}")
    print(f"   Passed: {meta['passed_features']} (stored in {args.state_file})")
    print(f"   Pending: {meta['pending_features']}")
    print(f"   Progress: {meta['completion_percentage']}%")
    
    # Print priority breakdown
    priority_counts = {}
    for f in features_json["features"]:
        p = f["priority"]
        priority_counts[p] = priority_counts.get(p, 0) + 1
    
    print("\n   Pending by priority:")
    for p in ["critical", "high", "medium", "low"]:
        if p in priority_counts:
            print(f"     {p}: {priority_counts[p]}")
    
    # Print state file info
    passed_data = state_manager.get_passed_features_data()
    if passed_data:
        print(f"\n📁 Passed features saved to: {args.state_file}")
        print(f"   Total passed: {len(passed_data)}")


if __name__ == "__main__":
    main()