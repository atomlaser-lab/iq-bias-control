import sys
import csv
"""
Creates a webpage listing the parts in an HTML table for keeping track
of soldering.
"""

#
# Open file and create a CSV reader object from the input file
# i.e. the bill of materials (BOM)
#
file = open(sys.argv[1],'r')
f = csv.reader(file,delimiter=',',quotechar='\"')
#
# This creates the header for the HTML page
#
html = """
<!DOCTYPE html>
<html lang="en-US">
<head>
    <meta charset="UTF-8">
    <title>Part List</title>
    <style type="text/css">
        table {
            border-collapse: collapse;
            width: 100%;
            max-width: 400px;
        }
        tr.group-header {
            background-color: #AAAAAA;
        }

        td {
            border: 1px solid black;
        }

        tr.component-added {
            background-color: red;
        }
    </style>

    <script type="text/javascript">
        function changeState(self,name) {
            var el = document.getElementById("row-" + name)
            if (self.checked) {
                el.classList.add("component-added")
            } else {
                el.classList.remove("component-added")
            }
        }
    </script>
</head>
<body>
    <table>
"""
#
# Loop over rows in the BOM. Drop the first row because it is just a header
#
nn = 0
for row in f:
    if nn == 0:
        nn += 1
        continue

    s = """
    <tr class="group-header">
        <td colspan="3" class="group-hear">{digikey}</td>
    </tr>
    """.format(digikey=row[4])
    s2 = ""
    for component in row[0].split(','):
        if len(component.strip()) == 0:
            continue
        s2 += """
        <tr class="component" id="row-{comp}">
            <td class="component">{comp}</td>
            <td class="component">{val}</td>
            <td class="component"><input type="checkbox" onclick="changeState(this,'{comp}');">
        </tr>
        """.format(comp=component.strip(),val=row[2])
    html += s + s2

html += """
    </table>
</body>
"""

file.close()
file = open("PartList.html","w")
file.write(html)
file.close()
