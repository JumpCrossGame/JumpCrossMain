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
    mapping(address => uint256) public rewards;
    IERC20 public jcc; // JumpCross Gaming coupon

    event Build(
        address indexed from, 
        string indexed level,
        string paymentId, 
        uint256 amount, 
        uint256 includeFee
    );
    event Create(
        address indexed from, 
        string indexed mapId, 
        string paymentId, 
        uint8 mode, 
        uint256 amount, 
        uint256 includeFee
    );
    event Ready(
        address indexed from, 
        string indexed mapId, 
        string paymentId,
        uint256 amount, 
        uint256 includeFee
    );
    event Upload(address indexed player, string indexed mapId, uint256 spent);
    event Settle(string indexed mapId, address indexed Builder, uint256 revenue);
    event Share(string indexed mapId, uint256 revenue);
    event Distribute(string indexed mapId, address indexed winner, uint256 distribution);

    error InvalidProtocolFee();
    error InvalidParam();

    constructor(address _jcc) Ownable(_msgSender()) ReentrancyGuard() {
        jcc = IERC20(_jcc);
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

        emit Build(from, level, paymentId, amount, includeFee);
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

        emit Create(from, mapId, paymentId, mode, amount, includeFee);
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

        emit Ready(from, mapId, paymentId, amount, includeFee);
    }

    /// @notice This function called when user is ready at a map, leaving a relevant record for game settlement.
    /// @dev Records playing data related to the map, used for distribute reward.
    /// @param mapId A map attribute used to search the map.
    /// @param useTime The time user spend playing the map. If user don't complete the game, useTime will be MaxUint256.
    function upload(address player, string memory mapId, uint256 useTime) external onlyOwner {
        emit Upload(player, mapId, useTime);
    }

    /// @notice This function will be called at the end of a game period to distribute rewards to the specified players.
    /// @dev The rewards assigned to each winner will be recorded, and each player must call claim() to claim their own
    /// rewards. Ex: rewards[winners[0]] += distribution[0]
    /// @param mapId A map attribute used to search the map.
    /// @param mapBuilder The map builder address.
    /// @param builderReward The reward for the map builder.
    /// @param protocolRevenue The revenue for the protocol, will be used to game operation.
    /// @param winners A map attribute used to search the map.
    /// @param distributions The time user spend playing the map. If user don't complete the game, useTime will be
    /// MaxUint256.
    function settle(
        string memory mapId,
        address mapBuilder,
        uint256 builderReward,
        uint256 protocolRevenue,
        address[] calldata winners,
        uint256[] calldata distributions
    ) external onlyOwner {
        if (winners.length != distributions.length) {
            revert InvalidParam();
        }

        rewards[mapBuilder] += builderReward;
        emit Settle(mapId, mapBuilder, builderReward);

        address owner = owner();
        rewards[owner] += protocolRevenue;
        emit Share(mapId, protocolRevenue);

        for (uint256 i = 0; i < winners.length; i++) {
            address winner = winners[i];
            uint256 reward = distributions[i];
            rewards[winner] += reward;
            emit Distribute(mapId, winner, reward);
        }
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
        address owner = owner();
        rewards[owner] += includeFee;
    }
}
