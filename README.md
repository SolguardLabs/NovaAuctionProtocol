# Nova Auction Protocol

![banner](./assets/banner.png)

NovaAuctionProtocol es una implementación EVM de subastas de liquidación para
collateral incautado. El protocolo permite vender collateral a cambio de deuda
estable mediante pujas competitivas, con extensión anti-sniping cuando una puja
llega cerca del cierre.

La arquitectura separa vaults, motor de liquidación, pricing de subastas,
tesorería, rewards de keepers, vistas agregadas y controles de seguridad.

## Componentes

```text
src/
  core/                 Vault, liquidation engine y auction house
  governance/           Configuración, roles y timelock auxiliar
  interfaces/           Interfaces públicas del protocolo
  lens/                 Vistas agregadas y analytics de subastas
  libraries/            Tipos, matemáticas, pricing y helpers de estado
  oracle/               Oráculo de precios
  periphery/            Router y batch actions
  rewards/              Créditos de keepers
  risk/                 Motor de consultas de riesgo
  security/             Ownable2Step, pausable y reentrancy guard
  tokens/               nUSD y collateral ERC20
  treasury/             Accounting de settlement, surplus y shortfall
```

## Flujo principal

1. Un borrower deposita collateral y abre deuda estable.
2. Si su health factor cae por debajo del umbral configurado, el liquidation
   engine incauta collateral.
3. El auction house inicia una subasta por un `debtTarget`.
4. Los bidders compiten con bids en nUSD.
5. Una puja cerca del cierre extiende `endTime`.
6. Al finalizar, `settle` transfiere la deuda ganadora a treasury.
7. El ganador llama `claimCollateral` y recibe el collateral adjudicado.

## Seguridad y controles

- Roles separados para gobierno, liquidación, pausa y configuración.
- Pricing de subasta aislado en librerías dedicadas.
- Extensión anti-sniping parametrizada por ventana y duración.
- Settlement separado de claim de collateral.
- Accounting de treasury para surplus, shortfall y recuperación.
- Vistas de riesgo y analytics para keepers e integradores.

Consulta [SECURITY.md](./SECURITY.md) para el alcance de revisión, las
invariantes esperadas y el proceso de reporte responsable.

## Requisitos

- Foundry con `forge`, `cast` y `anvil`.
- Git si se quiere reinstalar `forge-std`.
- Bash para los scripts auxiliares.

## Instalación

```bash
bash scripts/bootstrap.sh
forge build
```

## Pruebas

```bash
forge test
forge test -vvv
```

La suite cubre:

- `startAuction`;
- `bid`;
- extensión anti-sniping;
- `settle`;
- `cancel`;
- `claimCollateral`;
- accounting de treasury y rewards de keepers.

## LOC

El repositorio incluye un verificador de tamaño para mantener `src/` dentro del
rango operativo definido:

```bash
bash scripts/check-loc.sh
```
