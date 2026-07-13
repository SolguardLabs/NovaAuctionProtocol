# Política de seguridad

Nova Auction Protocol protege subastas de liquidación, custodia temporal de
collateral, settlement de deuda y accounting de tesorería. Esta política define
el alcance de revisión y las invariantes esperadas para cambios en el sistema.

## Alcance

Dentro del alcance:

- `src/core/NovaAuctionHouse.sol`;
- `src/core/NovaVault.sol`;
- `src/core/NovaLiquidationEngine.sol`;
- `src/libraries/AuctionPricing.sol`;
- `src/lens/*`;
- `src/periphery/*`;
- módulos de treasury, rewards, risk y security.

Fuera del alcance:

- parámetros de despliegue de ejemplo;
- infraestructura off-chain de keepers;
- interfaces externas no mantenidas en este repositorio;
- gestión de claves y cuentas operativas.

## Invariantes esperadas

- Una subasta solo puede iniciarse para collateral liquidado y deuda objetivo
  válida.
- Las bids deben respetar el precio mínimo y el estado temporal de la subasta.
- Las extensiones anti-sniping deben preservar reglas de pricing y settlement.
- `settle` debe cerrar la subasta antes de permitir claim de collateral.
- El collateral adjudicado solo puede reclamarse por el ganador.
- Treasury debe reflejar deuda recuperada, surplus y shortfall de forma
  consistente.

## Validación local

```bash
forge fmt --check
forge build
forge test
bash scripts/check-loc.sh
```

## Reporte responsable

Un reporte debe incluir:

- contrato y función afectados;
- secuencia mínima de verificación;
- timestamps y parámetros relevantes;
- bid, deuda objetivo y estado de la subasta;
- impacto económico;
- propuesta de mitigación;
- tests recomendados.

No incluyas claves privadas, credenciales ni datos de terceros.
