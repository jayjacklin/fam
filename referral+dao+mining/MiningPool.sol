// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./TokenWrapper.sol";
import "./SafeERC20.sol";
import "./Ownable.sol";

interface IReferralPool {
    function bindReferrer(address _invitee, address _referrer) external;

    function getReferrer(address account) external view returns (address);
}

contract MiningPool is TokenWrapper, Ownable {
    using SafeERC20 for IERC20;
    IERC20 public rewardToken;
    IReferralPool public referralPool;

    address public defaultMiner;

    uint256 public duration;
    uint256 public initReward;
    uint256 public startTime;
    uint256 public periodFinish;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => mapping(uint256 => uint256)) public tLevelRewards;

    mapping(address => uint256) public totalWithdarawnRewards;

    address[] internal users;
    mapping(address => uint256) public uid;

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardReferral(address indexed txer, address indexed receipient, uint256 reward);

    constructor(
        address rewardToken_,
        address stakeToken_,
        address referralPool_,
        address defaultMiner_,
        uint256 startTime_,
        uint256 initReward_,
        uint256 duration_
    ) {
        startTime = startTime_;
        duration = duration_;
        initReward = initReward_;
        defaultMiner = defaultMiner_;
        rewardToken = IERC20(rewardToken_);
        token = IERC20(stakeToken_);
        referralPool = IReferralPool(referralPool_);
        users.push(address(0));
        _notifyRewardAmount();
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        if (block.timestamp >= startTime) {
            lastUpdateTime = lastTimeRewardApplicable();
        }
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (block.timestamp < startTime || totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return
            ((lastTimeRewardApplicable() - lastUpdateTime) *
                rewardRate *
                1e18) /
            totalSupply() +
            rewardPerTokenStored;
    }

    function earned(address account) public view returns (uint256) {
        return
            (balanceOf(account) *
                (rewardPerToken() - userRewardPerTokenPaid[account])) /
            1e18 +
            rewards[account];
    }

    function stake(uint256 amount) public override updateReward(_msgSender()) {
        require(amount > 0, "Cannot stake 0");
        require(block.timestamp > startTime, "Wait to open");
        super.stake(amount);
        emit Staked(_msgSender(), amount);
        if (uid[_msgSender()] == 0) {
            uid[_msgSender()] = users.length;
            users.push(_msgSender());
        }
    }

    function withdraw(uint256 amount)
        public
        override
        updateReward(_msgSender())
    {
        require(amount > 0, "Cannot withdraw 0");
        super.withdraw(amount);
        address _caller = _msgSender();
        if (balanceOf(_caller) == 0) {
            users[uid[_caller]] = users[getAccountLength() - 1];
            uid[_caller] = 0;
            users.pop();
        }
        emit Withdrawn(_caller, amount);
    }

    function _transferL1Reward(
        address _caller,
        uint256 _a,
        address previousReferrer,
        uint256 _b
    ) private {
        rewardToken.safeTransfer(_caller, _a);
        rewardToken.safeTransfer(previousReferrer, _b);
        tLevelRewards[previousReferrer][0] += _b;
        emit RewardReferral(_caller, previousReferrer, _b);
    }

    function _transferL2Reward(
        address _caller,
        uint256 _a,
        address reffer2,
        uint256 _c
    ) private {
        rewardToken.safeTransfer(_caller, _a);
        rewardToken.safeTransfer(reffer2, _c);
        tLevelRewards[reffer2][1] += _c;
        emit RewardReferral(_caller, reffer2, _c);
    }

    function getReward() public updateReward(_msgSender()) {
        address _caller = _msgSender();
        uint256 reward = earned(_caller);
        if (reward == 0) {
            return;
        }
        rewards[_caller] = 0;

        address previousReferrer = referralPool.getReferrer(_caller);
        if (previousReferrer == address(0)) {
            uint256 _a = (reward * 80) / 100;
            uint256 _b = (reward * 20) / 100;
            rewardToken.safeTransfer(_caller, _a);
            rewardToken.safeTransfer(defaultMiner, _b);
        } else if (referralPool.getReferrer(previousReferrer) == address(0)) {
            uint256 _a = (reward * 80) / 100;
            uint256 _b = (reward * 20) / 100;
            uint256 _c = (reward * 5) / 100;
            uint256 _d = (reward * 15) / 100;
            if (balanceOf(previousReferrer) == 0) {
                rewardToken.safeTransfer(_caller, _a);
                rewardToken.safeTransfer(defaultMiner, _b);
            } else {
                _transferL1Reward(_caller, _a, previousReferrer, _d);
                rewardToken.safeTransfer(defaultMiner, _c);
            }
        } else {
            address reffer2 = referralPool.getReferrer(previousReferrer);
            if (balanceOf(previousReferrer) == 0 && balanceOf(reffer2) == 0) {
                uint256 _a = (reward * 80) / 100;
                uint256 _b = (reward * 20) / 100;
                rewardToken.safeTransfer(_caller, _a);
                rewardToken.safeTransfer(defaultMiner, _b);
            } else {
                uint256 _a = (reward * 80) / 100;
                uint256 _b = (reward * 15) / 100;
                uint256 _c = (reward * 5) / 100;
                if (balanceOf(previousReferrer) == 0) {
                    _transferL2Reward(_caller, _a, reffer2, _c);
                    rewardToken.safeTransfer(defaultMiner, _b);
                } else if (balanceOf(reffer2) == 0) {
                    _transferL1Reward(_caller, _a, previousReferrer, _b);
                    rewardToken.safeTransfer(defaultMiner, _c);
                } else {
                    _transferL1Reward(_caller, _a, previousReferrer, _b);
                    rewardToken.safeTransfer(reffer2, _c);
                    tLevelRewards[reffer2][1] += _c;
                    emit RewardReferral(_caller, reffer2, _c);
                }
            }
        }
        totalWithdarawnRewards[_caller] += reward;
        emit RewardPaid(_caller, reward);
    }

    function getAccountLength() public view returns (uint256) {
        return users.length;
    }

    function exit() public {
        withdraw(balanceOf(_msgSender()));
        getReward();
    }

    function getAllAccount() public view returns (address[] memory) {
        return users;
    }

    function getAccountList(uint256 index) public view returns (address) {
        if (index > users.length - 1) {
            return address(0);
        }
        return users[index];
    }

    function getAccountLimit(uint256 start, uint256 limit) public view returns(address[] memory) {
        if (start > users.length - 1) {
            return new address[](0);
        }
        uint256 end = 0;
        if (start + limit > users.length - 1) {
            end = users.length - start;
        } else {
            end = start + limit;
        }
        address[] memory _users = new address[](end);
        for (uint256 i = start; i < end; i++) {
            _users[i] = users[i];
        }
        return _users;
    }

    function _notifyRewardAmount() internal {
        rewardRate = initReward / duration;
        periodFinish = startTime + duration;
        emit RewardAdded(initReward);
    }

    // function updateRewardRate(uint256 initReward_, uint256 duration_) public onlyOwner {
    //     require(duration_ > 0, '[updateRewardRate]: duration should greater than 0');
    //     initReward = initReward_;
    //     duration = duration_;
    //     _notifyRewardAmount();
    // }

    // function updateInitreward(uint256 initReward_) public onlyOwner {
    //     require(initReward_ >= 0, '[updateInitreward]: greater than 0');
    //     initReward = initReward_;
    //     _notifyRewardAmount();
    // }

    // function updateDuration(uint256 duration_) public onlyOwner {
    //     require(duration_ > 0, '[updateDuration]: greater than 0');
    //     duration = duration_;
    //     _notifyRewardAmount();
    // }

    // function setStartTime(uint256 startTime_) public onlyOwner {
    //     startTime = startTime_;
    // }

    // function claimReceiver(address _token, address _receiver, uint256 _amount) public onlyOwner {
    //     IERC20(_token).safeTransfer(_receiver, _amount);
    // }
}
