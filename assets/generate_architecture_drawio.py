#!/usr/bin/env python3
"""
Generates assets/agentgateway-santi-open-architecture.drawio in the house style
(aws4 icons 78x78, white stroke, solid pastel groups, black orthogonal arrows, red annotations).
Run: python assets/generate_architecture_drawio.py && draw.io CLI export (see README).
Copyright 2026 Santiago Garcia Arango - Apache 2.0
"""
from pathlib import Path
from xml.sax.saxutils import escape

OUT = Path(__file__).with_name("agentgateway-santi-open-architecture.drawio")

ICON = ("sketch=0;points=[[0,0,0],[0.25,0,0],[0.5,0,0],[0.75,0,0],[1,0,0],[0,1,0],[0.25,1,0],[0.5,1,0],[0.75,1,0],[1,1,0],"
        "[0,0.25,0],[0,0.5,0],[0,0.75,0],[1,0.25,0],[1,0.5,0],[1,0.75,0]];outlineConnect=0;fontColor=#232F3E;fillColor={color};"
        "strokeColor=#ffffff;dashed=0;verticalLabelPosition=bottom;verticalAlign=top;align=center;html=1;fontSize=12;fontStyle=0;"
        "aspect=fixed;shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.{name};")
LABEL = "text;html=1;align=center;verticalAlign=middle;resizable=0;points=[];autosize=1;strokeColor=none;fillColor=none;fontSize=12;"
TITLE = "text;html=1;align=center;verticalAlign=middle;resizable=0;points=[];autosize=1;strokeColor=none;fillColor=none;fontSize=14;fontStyle=1;"
RED = "text;html=1;align=center;verticalAlign=middle;resizable=0;points=[];autosize=1;strokeColor=none;fillColor=none;fontColor=#FF0000;fontSize=12;fontStyle=1;"
GROUP = "rounded=1;whiteSpace=wrap;html=1;arcSize={arc};fillColor={fill};strokeColor={stroke};"
EDGE = ("edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;"
        "exitX={ex};exitY={ey};exitDx=0;exitDy=0;entryX={nx};entryY={ny};entryDx=0;entryDy=0;")
GENERIC = "rounded=1;whiteSpace=wrap;html=1;fillColor=#f5f5f5;strokeColor=#666666;fontColor=#333333;fontSize=12;"

COLORS = dict(net="#8C4FFF", compute="#ED7100", app="#E7157B", db="#C925D1", storage="#7AA116", ai="#01A88D", sec="#DD344C")

cells = []
_id = [0]


def nid(prefix="c"):
    _id[0] += 1
    return f"{prefix}{_id[0]}"


def cell(style, value, x, y, w, h, cid=None):
    cid = cid or nid()
    value = escape(value).replace("&amp;#10;", "&#10;")
    cells.append(f'<mxCell id="{cid}" value="{value}" style="{style}" vertex="1" parent="1">'
                 f'<mxGeometry x="{x}" y="{y}" width="{w}" height="{h}" as="geometry"/></mxCell>')
    return cid


def group(fill, stroke, x, y, w, h, title, arc=6, title_w=260):
    cell(GROUP.format(arc=arc, fill=fill, stroke=stroke), "", x, y, w, h)
    cell(TITLE, title, x + 8, y + 4, title_w, 26)


def icon(name, color, x, y, label, cid=None, size=78):
    cid = cell(ICON.format(color=color, name=name), "", x, y, size, size, cid)
    cell(LABEL, label, x - 16, y + size + 2, size + 32, 30)
    return cid


def edge(src, dst, ex, ey, nx, ny, points=None):
    pts = "".join(f'<mxPoint x="{px}" y="{py}"/>' for px, py in (points or []))
    arr = f'<Array as="points">{pts}</Array>' if points else ""
    cells.append(f'<mxCell id="{nid("e")}" style="{EDGE.format(ex=ex, ey=ey, nx=nx, ny=ny)}" edge="1" parent="1" source="{src}" target="{dst}">'
                 f'<mxGeometry relative="1" as="geometry">{arr}</mxGeometry></mxCell>')


def red(text, x, y, w=140):
    cell(RED, text, x, y, w, 20)


# ------------------------------------------------------------------ layout
cell("text;html=1;align=center;verticalAlign=middle;resizable=0;points=[];autosize=1;strokeColor=none;fillColor=none;fontSize=18;fontStyle=1;fontColor=#232F3E;",
     "agentgateway-santi-open · agentgateway on Amazon EKS Auto Mode: LLM-GW · MCP-GW · Inference Routing · Bedrock Guardrails", 330, 10, 1200, 30)

# AWS Cloud
cell(GROUP.format(arc=3, fill="#ffe6cc", stroke="#d79b00"), "", 300, 50, 1470, 830)
cell(TITLE, "AWS Cloud · us-east-1 · Account 430118815432", 312, 54, 360, 26)

# ---- Client side (outside AWS)
actor = cell("shape=actor;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;", "", 50, 340, 40, 60)
cell(LABEL, "Santi", 30, 402, 80, 20)
client = cell(GENERIC, "Clients&#10;OpenAI SDK · curl&#10;MCP Inspector · FastMCP Client", 120, 330, 160, 80)
red("only allow-listed /32 IPs", 120, 415, 160)
edge(actor, client, 1, 0.5, 0, 0.5)

# ---- VPC / EKS group (purple)
group("#e1d5e7", "#9673a6", 320, 90, 760, 575, "VPC 10.42.0.0/16 · EKS Auto Mode v1.36", title_w=330)

ctrl = icon("eks", COLORS["compute"], 380, 140, "agentgateway&#10;controller", cid="ctrl")
nlb = icon("network_load_balancer", COLORS["net"], 350, 330, "NLB internet-facing&#10;sourceRanges = my IP", cid="nlb")
agw = icon("eks", COLORS["compute"], 520, 330, "agentgateway proxy&#10;Gateway API data plane", cid="agw")
red("Gateway API · Pod Identity", 372, 292, 180)
edge(ctrl, agw, 1, 0.5, 0.5, 0, points=[(559, 179)])
red("xDS", 515, 240, 40)

# Inference sub-group (GPU)
cell(GROUP.format(arc=8, fill="#f0e6f6", stroke="#9673a6"), "", 700, 110, 360, 215)
cell(TITLE, "Inference NodePool · 2x g6.xlarge (NVIDIA L4)", 708, 114, 330, 26)
epp = icon("container_2", COLORS["compute"], 720, 180, "InferencePool + EPP&#10;(llm-d Router)", cid="epp")
ollama = icon("container_2", COLORS["compute"], 860, 180, "Ollama&#10;llama3.2:3b", cid="ollama")
gemma = icon("container_2", COLORS["compute"], 970, 180, "vLLM&#10;gemma-3-4b-it", cid="gemma")
edge(epp, ollama, 1, 0.5, 0, 0.5)
edge(epp, gemma, 0.5, 0, 0.5, 0, points=[(759, 158), (1009, 158)])
edge(agw, epp, 0.85, 0, 0, 0.5, points=[(586, 219), (700, 219)])
red("Inference&#10;Routing", 610, 190, 70)

# MCP sub-group
cell(GROUP.format(arc=8, fill="#f0e6f6", stroke="#9673a6"), "", 700, 385, 360, 125)
cell(TITLE, "ns mcp · sample MCP server (EKS)", 708, 389, 250, 26)
fastmcp = icon("container_2", COLORS["compute"], 960, 398, "FastMCP · /mcp&#10;Streamable HTTP", cid="fastmcp")
edge(agw, fastmcp, 1, 0.8, 0, 0.5, points=[(690, 392), (690, 437)])
red("MCP-GW /mcp", 720, 445, 90)

# Row C: NAT, general nodes, ESO
nat = icon("nat_gateway", COLORS["net"], 720, 545, "NAT Gateway&#10;egress only", cid="nat")
general = icon("container_2", COLORS["compute"], 850, 545, "General NodePool&#10;m7g.large/xlarge", cid="general")
eso = icon("container_2", COLORS["compute"], 960, 545, "External Secrets&#10;Operator", cid="eso")

edge(client, nlb, 1, 0.5, 0, 0.5)
edge(nlb, agw, 1, 0.5, 0, 0.5)
red("/v1/chat/completions&#10;/mcp · /agentcore/mcp", 290, 468, 200)

# ---- Bedrock group (green)
group("#d5e8d4", "#82b366", 1110, 90, 320, 250, "Amazon Bedrock · LLM-GW targets", title_w=280)
# Model icons on the top row, guardrail centered between them one row lower (no label overlap)
claude = icon("bedrock", COLORS["ai"], 1130, 130, "Claude 4.5&#10;Sonnet · Haiku", cid="claude")
gpt6 = icon("bedrock", COLORS["ai"], 1330, 130, "OpenAI GPT-6&#10;Luna · Sol", cid="gpt6")
guard = icon("bedrock", COLORS["ai"], 1230, 225, "Bedrock Guardrails&#10;PII · topics · attacks", cid="guard")
edge(agw, claude, 1, 0.3, 0, 0.5, points=[(1090, 353), (1090, 169)])
edge(agw, guard, 1, 0.62, 0, 0.5, points=[(1100, 378), (1100, 264)])
red("LLM-GW (Bedrock)", 800, 356, 120)
red("Guardrails", 1110, 272, 80)

# ---- AgentCore group (blue)
group("#dae8fc", "#6c8ebf", 1110, 370, 320, 145, "Amazon Bedrock AgentCore Runtime · MCP", title_w=290)
agentcore = icon("bedrock", COLORS["ai"], 1160, 400, "AgentCore Runtime&#10;FastMCP arm64 · JWT", cid="agentcore")
ecr = icon("ecr", COLORS["compute"], 1310, 400, "Amazon ECR&#10;2 repos (arm64)", cid="ecr")
edge(agw, agentcore, 1, 0.9, 0, 0.5, points=[(680, 400), (680, 520), (1095, 520), (1095, 439)])
red("MCP-GW /agentcore/mcp · JWT passthrough", 780, 526, 260)

# ---- Identity & secrets (red)
group("#f8cecc", "#b85450", 1110, 540, 320, 160, "Identity · Secrets", title_w=140)
# Secrets Manager sits next to External Secrets (short edge); Cognito reaches AgentCore through the
# free column between the AgentCore and ECR labels instead of crossing them.
secrets = icon("secrets_manager", COLORS["sec"], 1130, 580, "Secrets Manager&#10;OpenAI/Gemini keys", cid="secrets")
cognito = icon("cognito", COLORS["sec"], 1240, 580, "Amazon Cognito&#10;no self sign-up", cid="cognito")
iam = icon("identity_and_access_management", COLORS["sec"], 1350, 580, "IAM roles&#10;EKS Pod Identity", cid="iam")
edge(cognito, agentcore, 0.5, 0, 1, 0.5, points=[(1279, 439)])
edge(secrets, eso, 0, 0.5, 1, 0.5)
red("JWT", 1285, 517, 40)
red("sync&#10;keys", 1040, 556, 40)

# ---- External placeholders (outside AWS)
cell(GROUP.format(arc=6, fill="#f5f5f5", stroke="#666666"), "", 1470, 90, 280, 250)
cell(TITLE, "External LLM placeholders", 1478, 94, 220, 26)
openai = cell(GENERIC, "OpenAI API&#10;model: gpt-5.5&#10;(key from Secrets Manager)", 1500, 140, 220, 70)
gemini = cell(GENERIC, "Google Gemini API&#10;model: gemini-2.5-flash&#10;(key from Secrets Manager)", 1500, 240, 220, 70)
edge(agw, openai, 0, 0.85, 0, 0.5, points=[(480, 396), (480, 720), (1450, 720), (1450, 175)])
red("placeholders (via NAT)", 1480, 60, 150)

# ---- Observability / IaC legend (bottom)
cell(TITLE, "Observability · IaC", 330, 745, 200, 26)
cw = icon("cloudwatch_2", COLORS["app"], 350, 780, "CloudWatch&#10;Container Insights", cid="cw")
kms = icon("key_management_service", COLORS["sec"], 480, 780, "KMS&#10;secrets envelope", cid="kms")
cell(GENERIC, "Terraform (3 stacks)&#10;kubernetes · platform · agentgateway&#10;+ 7 Helm charts", 620, 790, 260, 60)
cell(GENERIC, "agentgateway UI :15000&#10;(kubectl port-forward)", 920, 790, 200, 60)

xml = f"""<mxfile host="app.diagrams.net" agent="Claude Code (san99tiago)">
  <diagram name="agentgateway-santi-open" id="agentgateway-santi-open-arch">
    <mxGraphModel dx="2000" dy="1100" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1800" pageHeight="920" math="0" shadow="0">
      <root>
        <mxCell id="0"/>
        <mxCell id="1" parent="0"/>
        {''.join(cells)}
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
"""
OUT.write_text(xml)
print("wrote", OUT, len(cells), "cells")
