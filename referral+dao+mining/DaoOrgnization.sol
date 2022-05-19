// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity ^0.8.0;

import "./Address.sol";
import "./Ownable.sol";
import "./SafeERC20.sol";

contract DaoOrgnization is Ownable {
    using SafeERC20 for IERC20;

    enum Period { THREE, NINE, TWELVE }

    address public esrowToken; // Reward Token Address
    uint256 public startTime;   // Release start time
    uint256 public baseUint = 30 days;   // Release cycle

    uint256 public tAmount3 = 260000 * 1e18;   // Total Rewards
    uint256 public tAmount9 = 1040000 * 1e18;   // Total Rewards
    uint256 public tAmount12 = 700000 * 1e18;   // Total Rewards

    uint256 public tCount3 = 147;  // Total addresses
    uint256 public tCount9 = 13;   // Total addresses
    uint256 public tCount12 = 7;   // Total addresses

    uint8[] public rRate3 = [40, 30, 30];   // Release rate
    uint8[] public rRate9 = [13, 12, 11, 11, 11, 11, 11, 11, 9];   // Release rate
    uint8[] public rRate12 = [11, 9, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8];   // Release rate

    mapping(Period => address[]) public accounts;     // Release account list
    mapping(Period => mapping(address => bool)) public validAccount;     // Is it a valid account
    mapping(Period => mapping(address => uint256)) public uidForPeriod;     // The uid of valid account

    mapping(Period => mapping(address => uint256)) public userReceivedForPeriod;   // User received rewards for period
    mapping(Period => uint256) public totalReceivedForPeriod;   // Total received rewards for period

    event Withdraw(address indexed account, Period indexed period, uint256 indexed amount);

    constructor(address _token, uint256 _startTime, uint256 _baseUint) {
        esrowToken = _token;
        baseUint = _baseUint;
        startTime = _startTime;
    }

    function getMin(uint256 a, uint256 b) private pure returns (uint256) {
        return a >= b ? b : a;
    }

    function getAccountsLength(Period _period) public view returns (uint256) {
        return accounts[_period].length;
    }

    function getAccount(Period _period, uint256 _index) public view returns (address) {
        require(_index < getAccountsLength(_period), "Index out of bounds");
        return accounts[_period][_index];
    }

    function getAllAccounts(Period _period) public view returns (address[] memory) {
        return accounts[_period];
    }

    function getCurrentMounth() public view returns (uint256) {
        if (startTime > 0) {
            return (block.timestamp - startTime) / baseUint;
        }
        return 0;
    }

    function tokenAvailable(uint256 _amount) private view returns (uint256) {
        return getMin(_amount, IERC20(esrowToken).balanceOf(address(this)));
    }

    function getTotalReceived(address _account) public view returns (uint256) {
        return  userReceivedForPeriod[Period.THREE][_account] +
                userReceivedForPeriod[Period.NINE][_account] +
                userReceivedForPeriod[Period.TWELVE][_account];
    }

    function getTotalReleasedForPeriod(Period _period, address _account) public view returns (uint256) {
        uint256 _cm = getCurrentMounth();
        uint256 _tr = 0;
        if (_period == Period.THREE && validAccount[Period.THREE][_account]) {
            uint256 count = getMin(_cm, rRate3.length);
            for (uint256 i = 0; i < count; i++) {
                _tr += tAmount3 * rRate3[i] / 100 / tCount3;
            }
        }
        if (_period == Period.NINE && validAccount[Period.NINE][_account]) {
            uint256 count = getMin(_cm, rRate9.length);
            for (uint256 i = 0; i < count; i++) {
                _tr += tAmount9 * rRate9[i] / 100 / tCount9;
            }
        }
        if (_period == Period.TWELVE && validAccount[Period.TWELVE][_account]) {
            uint256 count = getMin(_cm, rRate12.length);
            for (uint256 i = 0; i < count; i++) {
                _tr += tAmount12 * rRate12[i] / 100 / tCount12;
            }
        }
        return _tr;
    }

    function getTotalReleased(address _account) public view returns (uint256) {
        uint256 _cm = getCurrentMounth();
        uint256 _tr = 0;
        if (validAccount[Period.THREE][_account]) {
            uint256 count = getMin(_cm, rRate3.length);
            for (uint256 i = 0; i < count; i++) {
                _tr += tAmount3 * rRate3[i] / 100 / tCount3;
            }
        }
        if (validAccount[Period.NINE][_account]) {
            uint256 count = getMin(_cm, rRate9.length);
            for (uint256 i = 0; i < count; i++) {
                _tr += tAmount9 * rRate9[i] / 100 / tCount9;
            }
        }
        if (validAccount[Period.TWELVE][_account]) {
            uint256 count = getMin(_cm, rRate12.length);
            for (uint256 i = 0; i < count; i++) {
                _tr += tAmount12 * rRate12[i] / 100 / tCount12;
            }
        }
        return _tr;
    }

    function getReleaseAvailable(Period _period, address _account) public view returns (uint256) {
        if (!validAccount[_period][_account]) {
            return 0;
        }
        uint256 _received = userReceivedForPeriod[_period][_account];
        uint256 _cm = getCurrentMounth();
        uint256 _tr = 0;
        if (_period == Period.THREE && _cm < rRate3.length) {
            for (uint256 i = 0; i < _cm; i++) {
                _tr += tAmount3 * rRate3[i] / 100 / tCount3;
            }
            return _tr - _received;
        }
        if (_period == Period.NINE && _cm < rRate9.length) {
            for (uint256 i = 0; i < _cm; i++) {
                _tr += tAmount9 * rRate9[i] / 100 / tCount9;
            }
            return _tr - _received;
        }
        if (_period == Period.TWELVE && _cm < rRate12.length) {
            for (uint256 i = 0; i < _cm; i++) {
                _tr += tAmount12 * rRate12[i] / 100 / tCount12;
            }
            return _tr - _received;
        }
        return 0;
    }
    
    function _transferToken(address _account, Period _period, uint256 _amount) internal {
        if (_amount > 0) {
            IERC20(esrowToken).safeTransfer(_account, _amount);
            totalReceivedForPeriod[_period] += _amount;
            userReceivedForPeriod[_period][_account] += _amount;
            emit Withdraw(_account, _period, _amount);
        }
    }

    function withdraw() public {
        require(esrowToken != address(0), "esrowToken need to be set");
        address _caller = _msgSender();

        if (getReleaseAvailable(Period.THREE, _caller) > 0) {
            _transferToken(_caller, Period.THREE, getReleaseAvailable(Period.THREE, _caller));
        }
        if (getReleaseAvailable(Period.NINE, _caller) > 0) {
            _transferToken(_caller, Period.NINE, getReleaseAvailable(Period.NINE, _caller));
        }
        if (getReleaseAvailable(Period.TWELVE, _caller) > 0) {
            _transferToken(_caller, Period.TWELVE, getReleaseAvailable(Period.TWELVE, _caller));
        }

    }

    function withdraw(Period _period) public {
        require(esrowToken != address(0), "esrowToken need to be set");
        address _caller = _msgSender();
        require(validAccount[_period][_caller], "invalid account");
        uint256 _ra = getReleaseAvailable(_period, _caller);
        if (_ra > 0) {
            IERC20(esrowToken).safeTransfer(_caller, _ra);
            totalReceivedForPeriod[_period] += _ra;
            userReceivedForPeriod[_period][_caller] += _ra;
            emit Withdraw(_caller, _period, _ra);
        }
    }

    function addToPeriodList(Period _period, address[] memory _accounts) public onlyOwner {
        for (uint256 i = 0; i < _accounts.length; i++) {
            if (!validAccount[_period][_accounts[i]]) {
                uidForPeriod[_period][_accounts[i]] = getAccountsLength(_period);
                validAccount[_period][_accounts[i]] = true;
                accounts[_period].push(_accounts[i]);
            }
        }
    }

    function removeFromPeriodList(Period _period, address[] memory _accounts) public onlyOwner {
        for (uint256 i = 0; i < _accounts.length; i++) {
            if (validAccount[_period][_accounts[i]]) {
                address lastAccount = accounts[_period][getAccountsLength(_period) - 1];
                accounts[_period][uidForPeriod[_period][_accounts[i]]] = lastAccount;
                uidForPeriod[_period][lastAccount] = uidForPeriod[_period][_accounts[i]];
                accounts[_period].pop();
                delete uidForPeriod[_period][_accounts[i]];
                delete validAccount[_period][_accounts[i]];
            }
        }
    }

    function setBaseUint(uint256 _baseUint) public onlyOwner {
        require(baseUint > 0, "Zero");
        baseUint = _baseUint;
    }

    function setStartTime(uint256 _startTime) public onlyOwner {
        require(startTime > block.timestamp, "Launched");
        startTime = _startTime;
    }

    function receiveDividends(address _receiver, uint256 _amount) public onlyOwner {
        IERC20(esrowToken).safeTransfer(_receiver, _amount);
    }

}