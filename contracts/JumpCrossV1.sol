// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 *    ___                       _____
 *   |_  |                     /  __ \
 *     | |_   _ _ __ ___  _ __ | /  \/_ __ ___  ___ ___
 *     | | | | | '_ ` _ \| '_ \| |   | '__/ _ \/ __/ __|
 * /\__/ | |_| | | | | | | |_) | \__/| | | (_) \__ \__ \
 * \____/ \__,_|_| |_| |_| .__/ \____|_|  \___/|___|___/
 *                       | |
 *                       |_|
 *
 * Main contract for JumpCross game.
 */

/// @title JumpCrossV1
/// @author 0xmmq
/// @notice This contract is used to play JumpCross game.
contract JumpCrossV1 is Ownable, ReentrancyGuard {
    mapping(address => uint256) rewards;
    IERC20 public jcc; // JumpCross Gaming coupon

    event Build(string indexed paymentId, address indexed from, string indexed level, uint256 amount);
    event Create(string indexed paymentId, address indexed from, string indexed mapId, uint8 mode, uint256 amount);
    event Ready(string indexed paymentId, address indexed from, string indexed mapId, uint256 amount);
    event Upload(address indexed from, string indexed mapId, uint256 spent);
    event Settle(string indexed mapId, address[] indexed winners, uint256[] rewards);

    error InvalidProtocolFee();
    error InvalidParam();

    constructor() Ownable(_msgSender()) ReentrancyGuard() {
        jcc = IERC20(0xD59BE5afE8cF939BfFBC1Cb3D2c5545eBD8A7917);
    }

    /// @notice This function called when user builds a map, leaving a relevant record for game settlement.
    /// @dev Records information related to the map, used for backend verification.
    /// @param paymentId A unique string is used to verify data passed by user.
    /// @param level A map attribute used to potentially inform reward and risk. Ex: "bronze", "silver", "gold".
    /// @param amount The amount of coupon used to build a map.(including protocol fee)
    /// @param includeFee The amount of coupon used to pay protocol fee.
    function buildMap(string memory paymentId, string memory level, uint256 amount, uint256 includeFee) external {
        address from = _msgSender();
        _pay(from, amount, includeFee);

        emit Build(paymentId, from, level, amount);
    }

    /// @notice This function called when user creates a map, leaving a relevant record for game settlement.
    /// @dev Records information related to the map, used for backend verification.
    /// @param paymentId A unique string is used to verify data passed by user.
    /// @param mapId A map attribute used to search the map.
    /// @param mode A map attribute used to inform the backend if the map is public or private.
    /// Ex: {0: "public", 1: "private"}
    /// @param amount The amount of coupon used to build a map.(including protocol fee)
    /// @param includeFee The amount of coupon used to pay protocol fee.
    function createSpace(
        string memory paymentId,
        string memory mapId,
        uint8 mode,
        uint256 amount,
        uint256 includeFee
    ) external {
        address from = _msgSender();
        _pay(from, amount, includeFee);

        emit Create(paymentId, from, mapId, mode, amount);
    }

    /// @notice This function called when user is ready at a map, leaving a relevant record for game settlement.
    /// @dev Records information related to the map, used for backend verification.
    /// @param paymentId A unique string is used to verify data passed by user.
    /// @param mapId A map attribute used to search the map.
    /// @param amount The amount of coupon used to build a map.(including protocol fee)
    /// @param includeFee The amount of coupon used to pay protocol fee.
    function readyAt(string memory paymentId, string memory mapId, uint256 amount, uint256 includeFee) external {
        address from = _msgSender();
        _pay(from, amount, includeFee);

        emit Ready(paymentId, from, mapId, amount);
    }

    /// @notice This function called when user is ready at a map, leaving a relevant record for game settlement.
    /// @dev Records playing data related to the map, used for distribute reward.
    /// @param mapId A map attribute used to search the map.
    /// @param useTime The time user spend playing the map. If user don't complete the game, useTime will be MaxUint256.
    function upload(string memory mapId, uint256 useTime) external onlyOwner {
        emit Upload(_msgSender(), mapId, useTime);
    }

    /// @notice This function will be called at the end of a game period to distribute rewards to the specified players.
    /// @dev The rewards assigned to each winner will be recorded, and each player must call claim() to claim their own
    /// rewards. Ex: rewards[winners[0]] += distribution[0]
    /// @param mapId A map attribute used to search the map.
    /// @param winners A map attribute used to search the map.
    /// @param distribution The time user spend playing the map. If user don't complete the game, useTime will be
    /// MaxUint256.
    function settle(
        string memory mapId,
        address[] calldata winners,
        uint256[] calldata distribution
    ) external onlyOwner {
        if (winners.length != distribution.length) {
            revert InvalidParam();
        }

        for (uint256 i = 0; i < winners.length; i++) {
            address winner = winners[i];
            uint256 reward = distribution[i];
            rewards[winner] += reward;
        }

        emit Settle(mapId, winners, distribution);
    }

    /// @notice users can call this function to claim their rewards if they have rewards.
    function claim() external nonReentrant {
        address from = _msgSender();
        uint256 reward = rewards[from];
        rewards[from] = 0;
        jcc.transfer(from, reward);
    }

    /// @dev Helper function to receive game fee and protocol fee.
    function _pay(address from, uint256 amount, uint256 includeFee) internal {
        if (includeFee > amount) {
            revert InvalidProtocolFee();
        }

        jcc.transferFrom(from, address(this), amount);
        rewards[address(this)] += includeFee;
    }
}
