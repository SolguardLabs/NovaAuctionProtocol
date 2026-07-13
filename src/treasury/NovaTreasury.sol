// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { INovaConfigurator } from "../interfaces/INovaConfigurator.sol";
import { INovaTreasury } from "../interfaces/INovaTreasury.sol";
import { NovaTypes } from "../libraries/NovaTypes.sol";
import { SafeTransferLib } from "../libraries/SafeTransferLib.sol";
import { ReentrancyGuard } from "../security/ReentrancyGuard.sol";

contract NovaTreasury is INovaTreasury, ReentrancyGuard {
    using SafeTransferLib for address;

    error NotAuctionHouse();
    error NotSurplusOwner();
    error NoSurplus();

    INovaConfigurator public immutable configurator;

    mapping(address => NovaTypes.TreasurySnapshot) private _snapshots;
    mapping(address => mapping(address => uint256)) public surplusCredit;

    event AuctionSettlementRecorded(
        uint256 indexed auctionId,
        address indexed borrower,
        address indexed debtToken,
        uint256 winningBid,
        uint256 debtTarget,
        uint256 surplus,
        uint256 shortfall
    );
    event AuctionCancellationRecorded(
        uint256 indexed auctionId, address indexed borrower, address indexed debtToken
    );
    event SurplusWithdrawn(
        address indexed debtToken,
        address indexed account,
        address indexed recipient,
        uint256 amount
    );

    constructor(
        INovaConfigurator configurator_
    ) {
        configurator = configurator_;
    }

    modifier onlyAuctionHouse() {
        if (msg.sender != configurator.auctionHouse()) revert NotAuctionHouse();
        _;
    }

    function recordAuctionSettlement(
        uint256 auctionId,
        address borrower,
        address debtToken,
        uint256 winningBid,
        uint256 debtTarget
    ) external onlyAuctionHouse {
        NovaTypes.TreasurySnapshot storage snapshot = _snapshots[debtToken];
        uint256 surplus = winningBid > debtTarget ? winningBid - debtTarget : 0;
        uint256 shortfall = winningBid < debtTarget ? debtTarget - winningBid : 0;
        snapshot.totalDebtCollected += winningBid;
        snapshot.totalSurplusCredited += surplus;
        snapshot.totalShortfallBooked += shortfall;
        snapshot.settledAuctions += 1;
        if (surplus != 0) {
            surplusCredit[debtToken][borrower] += surplus;
        }
        emit AuctionSettlementRecorded(
            auctionId, borrower, debtToken, winningBid, debtTarget, surplus, shortfall
        );
    }

    function recordAuctionCancellation(
        uint256 auctionId,
        address borrower,
        address debtToken
    ) external onlyAuctionHouse {
        _snapshots[debtToken].cancelledAuctions += 1;
        emit AuctionCancellationRecorded(auctionId, borrower, debtToken);
    }

    function withdrawSurplus(
        address debtToken,
        address account,
        address recipient
    ) external nonReentrant returns (uint256 amount) {
        if (msg.sender != account && msg.sender != configurator.auctionHouse()) {
            revert NotSurplusOwner();
        }
        amount = surplusCredit[debtToken][account];
        if (amount == 0) revert NoSurplus();
        surplusCredit[debtToken][account] = 0;
        debtToken.safeTransfer(recipient, amount);
        emit SurplusWithdrawn(debtToken, account, recipient, amount);
    }

    function getSnapshot(
        address debtToken
    ) external view returns (NovaTypes.TreasurySnapshot memory snapshot) {
        return _snapshots[debtToken];
    }
}
