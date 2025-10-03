#!/usr/bin/env python3
"""
Automated Insight Finder - Discovers patterns in your memory
"""
import subprocess
import json
import sys
from datetime import datetime, timedelta

def search_memory(query):
    """Search memory and return results"""
    try:
        result = subprocess.run([
            'python3', 'ollama_embeddings.py', 'search', query
        ], capture_output=True, text=True, cwd='$HOME/Documents/GitHub/claude-memory-system/scripts')
        return result.stdout
    except Exception as e:
        return f"Error: {e}"

def generate_insights():
    """Generate automated insights from memory patterns"""
    
    insight_queries = [
        "breakthrough moment success achievement",
        "mistake error lesson learned failure", 
        "efficient solution elegant approach",
        "frustrating problem recurring issue",
        "person helpful valuable contact",
        "tool technology game changer",
        "idea concept potential opportunity",
        "warning sign red flag avoid"
    ]
    
    print("🧠 Automated Memory Insights")
    print("=" * 50)
    print(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    for i, query in enumerate(insight_queries, 1):
        print(f"## {i}. Pattern: '{query}'")
        print("-" * 30)
        
        results = search_memory(query)
        if "Found" in results and "results:" in results:
            # Extract just the top 3 results
            lines = results.split('\n')
            result_lines = []
            collecting = False
            count = 0
            
            for line in lines:
                if collecting and line.strip().startswith('[') and count < 3:
                    result_lines.append(line.strip())
                    count += 1
                elif "📊 Found" in line:
                    collecting = True
                    result_lines.append(line.strip())
                elif count >= 3:
                    break
            
            for line in result_lines:
                print(line)
        else:
            print("No clear patterns found")
        
        print()

if __name__ == "__main__":
    generate_insights()
