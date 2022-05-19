// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Ownable.sol";
import "./IERC20.sol";
import "./SafeERC20.sol";

contract ReferralPool is Ownable {
    using SafeERC20 for IERC20;

    address public DefaultRceipient = 0x3b39C360e35fF481527daab0c215E583105bD5d9;  // Default GOV

    address public rRewardToken; // Reward Token Address

    mapping(address => address) private referrer; // My recommended address (superior)
    mapping(address => address[]) private invitees; // User's inviter array mapping (subordinate list)
    mapping(address => uint256) public tRrewards; // Total Rewards Individuals Received
    uint8[] private rRate = [20, 10, 5];   // Reward rate 6%

    event BindReferrer(address indexed invitee, address indexed referrer);
    event ReferrerDividend(address indexed referrer, uint256 indexed amount);

    constructor(address _token) {
        rRewardToken = _token;
    }
  
    modifier onlyTokenCall() {
        require(_msgSender() == rRewardToken, 'Only be called by token');
        _;
    }

    function getMin(uint256 a, uint256 b) private pure returns (uint256) {
        return a >= b ? b : a;
    }

    // Referral revenue
    function dividendTo(address _txer, uint256 rewardsFee) external onlyTokenCall {
        if (rewardsFee == 0) {
            return;
        }

        address previousReferrer = referrer[_txer];
        uint256 n = 0;
        uint256 rt = 0;
        while (previousReferrer != address(0) && n < rRate.length) {
            uint256 rReward = rewardsFee * rRate[n] / 1000;
            bool success = IERC20(rRewardToken).transfer(previousReferrer, rReward);
            require(success, "bonusTo account: transfer failed!");

            emit ReferrerDividend(previousReferrer, rReward);

            tRrewards[previousReferrer] += rReward;
            rt += rReward;
            n++;
            previousReferrer = referrer[previousReferrer];
        }
        uint256 rtFee = getMin(IERC20(rRewardToken).balanceOf(address(this)), rewardsFee - rt);
        if (rtFee > 0) {
            bool success = IERC20(rRewardToken).transfer(DefaultRceipient, rtFee);
            require(success, "dividendTo: transfer failed!");
            tRrewards[DefaultRceipient] += rewardsFee;
        }

    }

    // Binding referrer relationship (binding superior)
    function bindReferrer(address _invitee, address _referrer) external onlyTokenCall {
        if (referrer[_invitee] == address(0) && _invitee != _referrer) {
            referrer[_invitee] = _referrer;
            invitees[_referrer].push(_invitee);
            emit BindReferrer(_invitee, _referrer);
        }
    }

    // Get the referrer address of the account
    function getReferrer(address account) public view returns (address) {
        return referrer[account];
    }

    // Get the direct push address of the account
    function getInvitee(address account, uint256 index) public view returns (address) {
        return invitees[account][index];
    }

    // Get the number of direct pushes for an account
    function getTInvitees(address account) public view returns (uint256) {
        return invitees[account].length;
    }

}