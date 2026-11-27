"""
tools_banco.py - DEMO banking tools for the Strands agents (static data, no real systems).

Every function is a Strands @tool. Select them by name with `--tools consulta_saldo,estado_canales`
or use all of them with `--tools all` (default). Add your own tool: define it here and register it
in TOOLS at the bottom.

Copyright 2026 Santiago Garcia Arango - Apache 2.0
"""
from __future__ import annotations

import datetime as dt

from strands import tool

# ---------------------------------------------------------------- demo data
_CUENTAS = {
    "ahorros-1234": {"titular": "Santiago G.", "tipo": "Ahorros", "saldo": 4_850_000.0, "moneda": "COP"},
    "corriente-5678": {"titular": "Santiago G.", "tipo": "Corriente", "saldo": 12_300_500.5, "moneda": "COP"},
    "usd-9012": {"titular": "Santiago G.", "tipo": "Ahorros USD", "saldo": 1_250.75, "moneda": "USD"},
}

_MOVIMIENTOS = {
    "ahorros-1234": [
        {"fecha": "2026-09-27", "descripcion": "Pago Nequi - Cafe Pergamino", "valor": -18_500},
        {"fecha": "2026-09-26", "descripcion": "Transferencia recibida - Nomina", "valor": 3_200_000},
        {"fecha": "2026-09-25", "descripcion": "Compra PSE - EPM Servicios", "valor": -245_300},
        {"fecha": "2026-09-24", "descripcion": "Retiro cajero - Poblado", "valor": -400_000},
        {"fecha": "2026-09-22", "descripcion": "Pago tarjeta credito", "valor": -1_150_000},
    ],
    "corriente-5678": [
        {"fecha": "2026-09-27", "descripcion": "Pago proveedor AWS", "valor": -2_980_000},
        {"fecha": "2026-09-26", "descripcion": "Factura cliente 0451", "valor": 6_400_000},
    ],
    "usd-9012": [
        {"fecha": "2026-09-20", "descripcion": "Deposito", "valor": 500.0},
    ],
}

_CANALES = [
    {"canal": "App movil", "estado": "OPERATIVO", "latencia_ms": 180, "disponibilidad_24h": "99.98%"},
    {"canal": "Banca web", "estado": "OPERATIVO", "latencia_ms": 240, "disponibilidad_24h": "99.95%"},
    {"canal": "Cajeros (ATM)", "estado": "DEGRADADO", "latencia_ms": 900, "disponibilidad_24h": "97.10%",
     "nota": "Intermitencia en la red de cajeros de Antioquia, en revision"},
    {"canal": "PSE", "estado": "OPERATIVO", "latencia_ms": 310, "disponibilidad_24h": "99.90%"},
    {"canal": "Sucursales", "estado": "OPERATIVO", "latencia_ms": 0, "disponibilidad_24h": "100%"},
    {"canal": "Transferencias interbancarias (ACH)", "estado": "MANTENIMIENTO", "latencia_ms": 0,
     "disponibilidad_24h": "95.00%", "nota": "Ventana programada 02:00-04:00 COT"},
]

_TASAS_COP = {"USD": 3_915.20, "EUR": 4_560.80, "MXN": 212.40, "BRL": 735.10}


# ---------------------------------------------------------------- tools
@tool
def consulta_saldo(cuenta: str) -> dict:
    """Consulta el saldo de una cuenta. Cuentas demo: ahorros-1234, corriente-5678, usd-9012."""
    info = _CUENTAS.get(cuenta.lower().strip())
    if not info:
        return {"error": f"cuenta '{cuenta}' no existe", "cuentas_disponibles": sorted(_CUENTAS)}
    return {"cuenta": cuenta, **info, "consultado": _ahora()}


@tool
def estado_canales(solo_incidentes: bool = False) -> list[dict]:
    """Estado de los canales digitales y fisicos del banco (app, web, cajeros, PSE, sucursales, ACH)."""
    canales = _CANALES
    if solo_incidentes:
        canales = [c for c in canales if c["estado"] != "OPERATIVO"]
    return canales


@tool
def movimientos(cuenta: str, ultimos: int = 5) -> dict:
    """Ultimos movimientos de una cuenta (por defecto 5, maximo 20)."""
    movs = _MOVIMIENTOS.get(cuenta.lower().strip())
    if movs is None:
        return {"error": f"cuenta '{cuenta}' no existe", "cuentas_disponibles": sorted(_MOVIMIENTOS)}
    return {"cuenta": cuenta, "movimientos": movs[: max(1, min(ultimos, 20))]}


@tool
def tasa_cambio(moneda: str = "USD", monto: float = 1.0) -> dict:
    """Tasa de cambio DEMO de una moneda a COP y conversion de un monto. Monedas: USD, EUR, MXN, BRL."""
    tasa = _TASAS_COP.get(moneda.upper().strip())
    if tasa is None:
        return {"error": f"moneda '{moneda}' no soportada", "monedas": sorted(_TASAS_COP)}
    return {"moneda": moneda.upper(), "tasa_cop": tasa, "monto": monto, "total_cop": round(monto * tasa, 2)}


_TARJETAS = {
    "visa-principal": {"franquicia": "Visa", "tipo": "Credito", "estado": "ACTIVA"},
    "mastercard-viajes": {"franquicia": "Mastercard", "tipo": "Credito", "estado": "ACTIVA"},
    "debito-ahorros": {"franquicia": "Visa Debito", "tipo": "Debito", "estado": "ACTIVA"},
}


@tool
def bloquear_tarjeta(tarjeta: str, motivo: str = "perdida") -> dict:
    """Bloquea (DEMO) una tarjeta identificada por su alias: visa-principal, mastercard-viajes o
    debito-ahorros. Motivos: perdida, robo, fraude. Las tarjetas se identifican por alias y NUNCA por
    numero: el Bedrock Guardrail bloquea cualquier digito de tarjeta (PII CREDIT_DEBIT_CARD_NUMBER)."""
    info = _TARJETAS.get(tarjeta.lower().strip())
    if not info:
        return {"error": f"tarjeta '{tarjeta}' no existe", "tarjetas_disponibles": sorted(_TARJETAS)}
    return {"tarjeta": tarjeta, **info, "estado": "BLOQUEADA", "motivo": motivo,
            "ticket": f"BLQ-{tarjeta[:4].upper()}-{_ahora()[11:19].replace(':', '')}", "hora": _ahora()}


@tool
def hora_colombia() -> str:
    """Fecha y hora actual en Colombia (UTC-5)."""
    return _ahora()


def _ahora() -> str:
    return dt.datetime.now(dt.timezone(dt.timedelta(hours=-5))).strftime("%Y-%m-%d %H:%M:%S COT")


# ---------------------------------------------------------------- registry
TOOLS = {
    "consulta_saldo": consulta_saldo,
    "estado_canales": estado_canales,
    "movimientos": movimientos,
    "tasa_cambio": tasa_cambio,
    "bloquear_tarjeta": bloquear_tarjeta,
    "hora_colombia": hora_colombia,
}


def select_tools(spec: str) -> list:
    """'all' -> every tool; 'none' -> []; 'consulta_saldo,estado_canales' -> those (dash or underscore)."""
    spec = (spec or "all").strip().lower()
    if spec == "all":
        return list(TOOLS.values())
    if spec == "none":
        return []
    chosen = []
    for name in spec.split(","):
        key = name.strip().replace("-", "_")
        if key not in TOOLS:
            raise SystemExit(f"tool desconocida '{name}'. Disponibles: {', '.join(TOOLS)}")
        chosen.append(TOOLS[key])
    return chosen
