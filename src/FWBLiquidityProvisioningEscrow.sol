// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.12;

import {IHypervisor} from "./external/IHypervisor.sol";
import {IWETH9} from "./external/IWETH9.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

/// @title Llama escrow contract between FWB and Gamma Strategies
/// @author Llama
contract FWBLiquidityProvisioningEscrow {
    using SafeERC20 for IERC20;

    // Temporarily setting WBTC-ETH Gamma Vault as placeholder -> Set later as FWB-ETH Gamma Vault
    IHypervisor private constant GAMMA_FWB_VAULT = IHypervisor(0x35aBccd8e577607275647edAb08C537fa32CC65E);
    IERC20 private constant FWB = IERC20(0x35bD01FC9d6D5D81CA9E055Db88Dc49aa2c699A8);
    IERC20 private constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IWETH9 private constant WETH9 = IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    // Should we have an ERC20 initialization for the gamma shares ??

    address private constant LLAMA_MULTISIG = 0xA519a7cE7B24333055781133B13532AEabfAC81b;
    address private constant FWB_MULTISIG = 0x660F6D6c9BCD08b86B50e8e53B537F2B40f243Bd;

    uint256 private gammaFwbWethSharesBalance;
    uint256 private fwbBalance;
    uint256 private wethBalance;

    error OnlyFWB();
    modifier onlyFWB() {
        if (msg.sender != FWB_MULTISIG) revert OnlyFWB();
        _;
    }

    error OnlyFWBLlama();
    modifier onlyFWBLlama() {
        if ((msg.sender != FWB_MULTISIG) && (msg.sender != LLAMA_MULTISIG)) revert OnlyFWBLlama();
        _;
    }

    error OnlyNonZeroAmount();
    modifier onlyNonZeroAmount(uint256 amount) {
        if (amount == 0) revert OnlyNonZeroAmount();
        _;
    }

    error CheckAmount();
    modifier checkAmount(uint256 amount, uint256 balance) {
        if (amount == 0 || amount > balance) revert CheckAmount();
        _;
    }

    function getFWBBalance() public view returns (uint256) {
        return fwbBalance;
    }

    function getWETHBalance() public view returns (uint256) {
        return wethBalance;
    }

    function getGammaFwbWethSharesBalance() public view returns (uint256) {
        return gammaFwbWethSharesBalance;
    }

    // What other checks are required ??
    function depositFWBToEscrow(uint256 _fwbAmount) external onlyFWB onlyNonZeroAmount(_fwbAmount) {
        fwbBalance += _fwbAmount;
        // Transfer token from FWB (sender). FWB (sender) must have first approved them.
        FWB.safeTransferFrom(msg.sender, address(this), _fwbAmount);
        assert(fwbBalance == FWB.balanceOf(address(this)));
    }

    // What other checks are required ??
    function withdrawFWBFromEscrow(uint256 _fwbAmount) external onlyFWB checkAmount(_fwbAmount, fwbBalance) {
        fwbBalance -= _fwbAmount;
        FWB.safeTransfer(msg.sender, _fwbAmount);
        assert(fwbBalance == FWB.balanceOf(address(this)));
    }

    // What other checks are required ??
    // Have to convert ETH to WETH after depositing ETH
    function depositETHToEscrow() external payable onlyFWB {
        wethBalance += msg.value;
        WETH9.deposit();
        assert(wethBalance == WETH.balanceOf(address(this)));
    }

    // What other checks are required ??
    // Have to convert WETH to ETH before withdrawing ETH
    function withdrawETHFromEscrow() external onlyFWB {}

    // What other checks are required ??
    function depositToGammaVault(uint256 _fwbAmount, uint256 _wethAmount)
        external
        onlyFWBLlama
        checkAmount(_fwbAmount, fwbBalance)
        checkAmount(_wethAmount, wethBalance)
    {
        // Should we be setting some values for these ??
        uint256[4] memory minIn = [uint256(0), uint256(0), uint256(0), uint256(0)];

        fwbBalance -= _fwbAmount;
        wethBalance -= _wethAmount;

        // Do we need to do an approval for FWB and WETH before this deposit ??
        uint256 gammaFwbWethShares = GAMMA_FWB_VAULT.deposit(
            _fwbAmount,
            _wethAmount,
            address(this),
            address(this),
            minIn
        );

        gammaFwbWethSharesBalance += gammaFwbWethShares;

        assert(fwbBalance == FWB.balanceOf(address(this)));
        assert(wethBalance == WETH.balanceOf(address(this)));
        // Should we have an assert for the gamma shares balance ??
    }

    // What other checks are required ??
    function withdrawFromGammaVault(uint256 _gammaFwbWethShares)
        external
        onlyFWBLlama
        checkAmount(_gammaFwbWethShares, gammaFwbWethSharesBalance)
    {
        // Should we be setting some values for these ??
        uint256[4] memory minAmounts = [uint256(0), uint256(0), uint256(0), uint256(0)];

        gammaFwbWethSharesBalance -= _gammaFwbWethShares;

        // Do we need to do an approval for gamma shares before this withdrawal ??
        (uint256 _fwbAmount, uint256 _wethAmount) = GAMMA_FWB_VAULT.withdraw(
            gammaFwbWethSharesBalance,
            address(this),
            address(this),
            minAmounts
        );

        fwbBalance += _fwbAmount;
        wethBalance += _wethAmount;

        assert(fwbBalance == FWB.balanceOf(address(this)));
        assert(wethBalance == WETH.balanceOf(address(this)));
        // Should we have an assert for the gamma shares balance ??
    }
}
