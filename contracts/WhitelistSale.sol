pragma solidity ^0.4.11;

import 'zeppelin-solidity/contracts/math/SafeMath.sol';

contract ERC20Constant {
    function balanceOf( address who ) constant returns (uint value);
}
contract ERC20Stateful {
    function transfer( address to, uint value) returns (bool ok);
}
contract ERC20Events {
    event Transfer(address indexed from, address indexed to, uint value);
}
contract ERC20 is ERC20Constant, ERC20Stateful, ERC20Events {}

contract Owned {
    address public owner;

    function Owned() {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) onlyOwner {
        owner = newOwner;
    }
}

contract WhitelistSale is Owned {

    ERC20 public manaToken;

    // Amount of MANA received per ETH
    uint256 public manaPerEth;

    // Sales start at this timestamp
    uint256 public initialTimestamp;

    // The sale goes on through 6 days. Each day, users are allowed to buy up to a certain amount of MANA.

    // This mapping stores the ETH that an user can spend. The array creates one such mapping for each day.
    mapping(address => uint256)[6] public allowOnDay;

    // The initial values allowed per day are copied from this array
    uint256[6] public limitPerDay;

    // The sale does not continue if this flag is set to true -- in case of emergency 
    bool public handbreak;

    event LogWithdrawal(uint256 _value);
    event LogBought(uint orderInMana);
    event LogUserAdded(address user);
    event LogUpdatedLimitPerDay(uint8 _day, uint256 amount);
    event LogUpdatedInitialTimestamp(uint256 _initialTimestamp);

    function WhitelistSale (
        ERC20 _manaToken,
        uint256 _initialTimestamp
    )
        Owned()
    {
        manaToken        = _manaToken;
        initialTimestamp = _initialTimestamp;

        manaPerEth       = 11954;
        limitPerDay[0]   = 3.3 ether;
        limitPerDay[1]   = 10 ether;
        limitPerDay[2]   = 30 ether;
        limitPerDay[3]   = 90 ether;
        limitPerDay[4]   = 450 ether;
        limitPerDay[5]   = 1500 ether;

        handbreak        = false;
    }

    // Pause the sale
    function activateHandbreak() onlyOwner {
        handbreak = true;
    }

    // Withdraw Mana (only owner)
    function withdrawMana(uint256 _value) onlyOwner returns (bool ok) {
        return withdrawToken(manaToken, _value);
    }

    // Withdraw any ERC20 token (just in case)
    function withdrawToken(address _token, uint256 _value) onlyOwner returns (bool ok) {
        return ERC20(_token).transfer(owner,_value);
        LogWithdrawal(_value);
    }

    // Withdraw proceeds
    function withdraw(uint256 _value) onlyOwner {
        require(this.balance >= _value);
        owner.transfer(_value);
        LogWithdrawal(_value);
    }

    // Calculate which day into the sale are we.
    function getDay() public returns (uint256) {
        return SafeMath.sub(block.timestamp, initialTimestamp) / 1 days;
    }

    modifier onlyIfActive {
        require(!handbreak);
        require(getDay() >= 0);
        require(getDay() < 6);
        _;
    }

    function buy(address beneficiary) payable onlyIfActive {
        require(beneficiary != 0);

        uint day = getDay();
        uint256 allowedForSender = allowOnDay[day][msg.sender];

        if (msg.value > allowedForSender) revert();

        uint256 balanceInMana = manaToken.balanceOf(address(this));

        uint orderInMana = msg.value * manaPerEth;
        if (orderInMana > balanceInMana) revert();

        allowOnDay[day][msg.sender] = SafeMath.sub(allowedForSender, msg.value);
        manaToken.transfer(beneficiary, orderInMana);

        LogBought(orderInMana);
    }

    // Add a user to the whitelist
    function addUser(address user) onlyOwner {
        for (uint8 _day = 0; _day < 6; _day++) {
            allowOnDay[_day][user] = limitPerDay[_day];
        }
        LogUserAdded(user);
    }

    function() payable {
        buy(msg.sender);
    }
}

