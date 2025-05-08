import pandas as pd

# Replace with the path to your actual CSV file
CSV_FILE = "todoist_export.csv"

# Load the CSV
df = pd.read_csv(CSV_FILE)

# Ensure INDENT is numeric
df["INDENT"] = pd.to_numeric(df["INDENT"], errors="coerce").fillna(1).astype(int)

# Reconstruct the indented outline
outline = ""
for _, row in df.iterrows():
    if row["TYPE"] != "task":
        continue  # skip sections, headers, etc.
    indent_level = row["INDENT"] - 1  # INDENT starts at 1, so subtract 1 for 0-based
    content = row["CONTENT"]
    outline += "  " * indent_level + "- " + content + "\n"

# Print the result
print(outline)
