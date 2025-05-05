import pandas as pd
from collections import defaultdict

# Replace this with your actual file path
CSV_FILE = 'todoist_export.csv'

# Load the CSV
df = pd.read_csv(CSV_FILE)

# Ensure ID and Parent columns are strings for consistent mapping
df['ID'] = df['ID'].astype(str)
df['Parent'] = df['Parent'].apply(lambda x: str(int(x)) if pd.notna(x) else None)

# Build dictionaries for tasks and child mapping
tasks = df.set_index("ID").to_dict(orient="index")
children_map = defaultdict(list)

for task_id, task in tasks.items():
    parent_id = task.get('Parent')
    if parent_id:
        children_map[parent_id].append(task_id)

# Recursive function to build an indented outline
def build_outline(task_id, level=0):
    content = tasks[task_id].get("Content", "(no content)")
    output = "  " * level + "- " + content + "\n"
    for child_id in children_map.get(task_id, []):
        output += build_outline(child_id, level + 1)
    return output

# Start from root-level tasks
outline = ""
for task_id, task in tasks.items():