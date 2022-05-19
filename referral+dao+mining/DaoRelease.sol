// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity ^0.8.0;

import "./Address.sol";
import "./Ownable.sol";
import "./SafeERC20.sol";
import "./ReentrancyGuard.sol";

contract DaoRelease is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public esrowToken; // Reward Token Address
    uint256 public baseUint = 30 days;   // Release cycle

    struct WayReleaseInfo {
        uint8 way;   // Release way
        uint8 months;   // Release cycle
        uint256 quota;  // Total quota for each address
        uint256 count;  // Total amount of addresses
        uint256 startTime;  // Release start time
    }
    mapping(uint8 => WayReleaseInfo) public wayReleaseInfo;     // Release way for config

    struct UserInfo {
        uint8 way;   // Release way
        uint256 uid;  // Uid in a way
        uint256 received;  // User received
    }

    mapping(address => UserInfo) public userInfo;     // User info

    mapping(uint8 => address[]) public accounts;     // Release account list
    mapping(uint8 => uint256) public totalReceivedForWay;   // Total received rewards for period
    uint8[] public ways;

    event Withdraw(address indexed account, uint8 indexed way, uint256 indexed amount);

    constructor(address _token, uint256 _baseUint) {
        esrowToken = _token;
        baseUint = _baseUint;
    }

    function getMin(uint256 a, uint256 b) private pure returns (uint256) {
        return a >= b ? b : a;
    }

    function getAccountsLength(uint8 _way) public view returns (uint256) {
        return accounts[_way].length;
    }

    function getAccount(uint8 _way, uint256 _index) public view returns (address) {
        require(_index < getAccountsLength(_way), "Index out of bounds");
        return accounts[_way][_index];
    }

    function getAllAccounts(uint8 _way) public view returns (address[] memory) {
        return accounts[_way];
    }

    function getCurrentMounth(uint8 _way) public view returns (uint256) {
        if (wayReleaseInfo[_way].startTime > 0) {
            return (block.timestamp - wayReleaseInfo[_way].startTime) / baseUint;
        }
        return 0;
    }

    function tokenAvailable(uint256 _amount) private view returns (uint256) {
        return getMin(_amount, IERC20(esrowToken).balanceOf(address(this)));
    }

    function getUserInfo(address _account)
        public
        view
        returns (uint8 way, uint256 uid, uint256 received)
    {
        return (userInfo[_account].way, userInfo[_account].uid, userInfo[_account].received);
    }

    function isListIn(address _account) public view returns (bool) {
        return userInfo[_account].way > 0;
    }

    function getWayReleaseInfo(uint8 _way)
        public
        view
        returns (
            uint8 months,
            uint256 quota,
            uint256 count,
            uint256 startTime
        )
    {
        return (
            wayReleaseInfo[_way].months,
            wayReleaseInfo[_way].quota,
            wayReleaseInfo[_way].count,
            wayReleaseInfo[_way].startTime
        );
    }

    function getTotalReleased(address _account) public view returns (uint256) {
        uint8 _userWay = userInfo[_account].way;
        uint256 _cm = getCurrentMounth(_userWay);

        if (_userWay != 0 && wayReleaseInfo[_userWay].months != 0) {
            uint256 count = getMin(_cm, wayReleaseInfo[_userWay].months);
            return count * wayReleaseInfo[_userWay].quota / wayReleaseInfo[_userWay].months;
        }
        return 0;
    }

    function getReleaseAvailable(address _account) public view returns (uint256) {
        return getTotalReleased(_account) - userInfo[_account].received;
    }
    
    function _transferToken(address _account, uint8 _way, uint256 _amount) internal {

        IERC20(esrowToken).safeTransfer(_account, _amount);
        totalReceivedForWay[_way] += _amount;
        userInfo[_account].received += _amount;
        emit Withdraw(_account, _way, _amount);
    }

    function withdraw() public nonReentrant {
        require(esrowToken != address(0), "esrowToken need to be set");
        address _caller = _msgSender();
        uint8 _userWay = userInfo[_caller].way;
        require(_userWay != 0, "Invalid address");
        uint256 availableAmt = getReleaseAvailable(_caller);
        require(availableAmt > 0, "No withdraw available");
        require(
            IERC20(esrowToken).balanceOf(address(this)) >= availableAmt,
            "Insufficient pool balance"
        );

        _transferToken(_caller, _userWay, availableAmt);

    }

    function _setWayReleaseInfo(
        uint8 _way,
        uint8 _months,
        uint256 _quota,
        uint256 _count,
        uint256 _startTime
    ) internal returns(bool){
        
        require(_way != 0, "Invalid way");
        require(_months != 0, "Invalid month");
        require(_quota != 0, "Invalid quota");
        require(_count != 0, "Invalid count");
        require(_startTime != 0, "Invalid start time");

        wayReleaseInfo[_way] = WayReleaseInfo({
            way: _way,
            months: _months,
            quota: _quota,
            count: _count,
            startTime: _startTime
        });
        ways.push(_way);
        return true;
    }

    function addWayReleaseInfo(
        uint8 _way,
        uint8 _months,
        uint256 _quota,
        uint256 _count,
        uint256 _startTime
    ) public onlyOwner {
        require(wayReleaseInfo[_way].months == 0, "Exist way");
        _setWayReleaseInfo(_way, _months, _quota, _count, _startTime);
    }

    function updateWayReleaseInfo(
        uint8 _way,
        uint8 _months,
        uint256 _quota,
        uint256 _count,
        uint256 _startTime
    ) public onlyOwner {
        require(wayReleaseInfo[_way].months != 0, "Not exist way");
        _setWayReleaseInfo(_way, _months, _quota, _count, _startTime);
    }

    error EXIST_WAY(uint8 way);

    function batchAddWayReleaseInfo(WayReleaseInfo[] memory _releaseInfoList) public onlyOwner {
        for (uint256 i = 0; i < _releaseInfoList.length; i++) {
            if (wayReleaseInfo[_releaseInfoList[i].way].months != 0) {
                revert EXIST_WAY(_releaseInfoList[i].way);
            }
            _setWayReleaseInfo(
                _releaseInfoList[i].way,
                _releaseInfoList[i].months,
                _releaseInfoList[i].quota,
                _releaseInfoList[i].count,
                _releaseInfoList[i].startTime
            );
        }
    }
    
    function removeWay(uint8 _way) public onlyOwner {
        require(wayReleaseInfo[_way].months != 0, "Not exist way");
        delete wayReleaseInfo[_way];
        for (uint256 i = 0; i < ways.length; i++) {
            if (_way == ways[i]) {
                ways[i] = ways[ways.length - 1];
                ways.pop();
            }
        }
    }

    error EXIST_USERWAY(address accout, uint8 way);

    function addToWayList(uint8 _way, address[] memory _accounts) public onlyOwner {
        for (uint256 i = 0; i < _accounts.length; i++) {
            require(getAccountsLength(_way) < wayReleaseInfo[_way].count, "Over count");
            if (userInfo[_accounts[i]].way != 0) {
                revert EXIST_USERWAY(_accounts[i], _way);
            }
            userInfo[_accounts[i]].uid = getAccountsLength(_way);
            userInfo[_accounts[i]].way = _way;
            accounts[_way].push(_accounts[i]);
        }
    }

    function removeFromWayList(address[] memory _accounts) public onlyOwner {
        for (uint256 i = 0; i < _accounts.length; i++) {
            uint8 _way = userInfo[_accounts[i]].way;
            if (_way != 0) {
                address lastAccount = accounts[_way][getAccountsLength(_way) - 1];
                accounts[_way][userInfo[_accounts[i]].uid] = lastAccount;
                userInfo[lastAccount].uid = userInfo[_accounts[i]].uid;
                accounts[_way].pop();
                delete userInfo[_accounts[i]].way;
                delete userInfo[_accounts[i]].uid;
            }
        }
    }

    function setBaseUint(uint256 _baseUint) public onlyOwner {
        require(baseUint > 0, "Zero");
        baseUint = _baseUint;
    }

    function setStartTime(uint8 _way, uint256 _startTime) public onlyOwner {
        require(wayReleaseInfo[_way].startTime > block.timestamp, "Launched");
        wayReleaseInfo[_way].startTime = _startTime;
    }

    function receiveDividends(address _receiver, uint256 _amount) public onlyOwner {
        IERC20(esrowToken).safeTransfer(_receiver, _amount);
    }

}