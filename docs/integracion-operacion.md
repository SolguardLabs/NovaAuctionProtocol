# Integración y operación local

## Comprobación de una revisión

```bash
bash scripts/bootstrap.sh
forge fmt --check
forge build
forge test
bash scripts/ci.sh
```

`bootstrap.sh` instala `forge-std` en `lib/` si falta; `lib/`, `out/` y `cache/` son artefactos locales ignorados. Para depurar un test, usar `forge test --match-test <nombre> -vvv`. El recuento `bash scripts/check-loc.sh` informa líneas físicas y no vacías, sin imponer un tamaño artificial.

## Lecturas para integradores

- `getAuction(id)` y `getClaim(id)` exponen estado de subasta y reclamación.
- `requiredBid(id)` y las vistas del lens ayudan a preparar una operación con datos del bloque consultado; deben leerse de nuevo antes de enviar una transacción en cualquier entorno de prueba.
- `NovaTreasury.getSnapshot(token)` contiene deuda cobrada, superávit y déficit registrados.
- `NovaAuctionAnalytics.aggregate`, `extensionReport`, `recoveryProfile` y `weightedRecoveryBps` ofrecen métricas de solo lectura para conjuntos pequeños y acotados de subastas; rangos muy amplios incrementan coste de consulta.

El script `script/DeployNova.s.sol` muestra el orden de construcción y enlace entre contratos. No incluye configuración, gobierno, keeper, monitorización ni autorización para una red pública. Para comparar dos revisiones, registrar SHA, parámetros de Foundry, tests, ABI y bytecode de los contratos económicos, además del resultado de CI.
