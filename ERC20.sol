// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

contract LuxuryXERC20Temp {
    // Reentrancy protection state
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    // Token Metadata
    string public constant name = "Industrial Fund";
    string public constant symbol = "$IND";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    // Token State
    address public owner;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // Security Features
    mapping(address => bool) private _isBlacklisted;
    mapping(address => bool) private _excludedFromFees;
    uint256 public buyTax;
    uint256 public sellTax;
    uint256 public maxWalletLimit;
    bool private _paused;

    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event FundsRecovered(address indexed token, address indexed to, uint256 amount);
    event Mint(address indexed account, uint256 amount);
    event Burn(address indexed account, uint256 amount);
    event Airdrop(address[] recipients, uint256[] amounts);
    event BlacklistUpdated(address indexed account, bool isBlacklisted);
    event FeesUpdated(uint256 buyTax, uint256 sellTax);
    event ExclusionUpdated(address indexed account, bool isExcluded);
    event MaxWalletLimitUpdated(uint256 newLimit);
    event TransferPaused(bool isPaused);

    constructor(uint256 initialSupply) {
        require(initialSupply > 0, "Initial supply must be greater than zero");
        _status = _NOT_ENTERED;
        owner = msg.sender;
        totalSupply = initialSupply * (10 ** uint256(decimals));
        balanceOf[owner] = totalSupply;
        emit Transfer(address(0), owner, totalSupply);
    }

    // SafeMath functions implemented directly
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }

    // Reentrancy guard
    modifier nonReentrant() {
        require(_status != _ENTERED, "Reentrant call detected");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    // Enhanced Blacklist Management
    function addToBlacklist(address account) external onlyOwner {
        require(account != address(0), "Cannot blacklist zero address");
        require(account != owner, "Cannot blacklist owner");
        require(account != address(this), "Cannot blacklist contract");
        require(!_isBlacklisted[account], "Address already blacklisted");

        _isBlacklisted[account] = true;
        emit BlacklistUpdated(account, true);
    }

    function removeFromBlacklist(address account) external onlyOwner {
        require(account != address(0), "Cannot unblacklist zero address");
        require(_isBlacklisted[account], "Address not blacklisted");

        _isBlacklisted[account] = false;
        emit BlacklistUpdated(account, false);
    }

    function destroyBlackFunds(address account) external onlyOwner nonReentrant {
        require(account != address(0), "Invalid address");
        require(account != owner, "Cannot destroy owner funds");
        require(_isBlacklisted[account], "Address not blacklisted");

        uint256 balance = balanceOf[account];
        require(balance > 0, "No balance to destroy");

        balanceOf[account] = 0;
        totalSupply = sub(totalSupply, balance);
        emit Transfer(account, address(0), balance);
    }

    // Fee Management with Strict Validation
    function setBuyTax(uint256 tax) external onlyOwner {
        require(tax <= 20, "Buy tax cannot exceed 20%");
        buyTax = tax;
        emit FeesUpdated(buyTax, sellTax);
    }

    function setSellTax(uint256 tax) external onlyOwner {
        require(tax <= 20, "Sell tax cannot exceed 20%");
        sellTax = tax;
        emit FeesUpdated(buyTax, sellTax);
    }

    function excludeFromFees(address account) external onlyOwner {
        require(account != address(0), "Cannot exclude zero address");
        require(!_excludedFromFees[account], "Already excluded");

        _excludedFromFees[account] = true;
        emit ExclusionUpdated(account, true);
    }

    function includeInFees(address account) external onlyOwner {
        require(account != address(0), "Cannot include zero address");
        require(_excludedFromFees[account], "Already included");

        _excludedFromFees[account] = false;
        emit ExclusionUpdated(account, false);
    }

    // Wallet Limit (kept as requested)
    function setMaxWalletLimit(uint256 limit) external onlyOwner {
        require(limit >= div(totalSupply, 100), "Limit too low"); // Minimum 1% of supply
        maxWalletLimit = limit;
        emit MaxWalletLimitUpdated(limit);
    }

    // Secure Token Operations with SafeMath
    function mint(address account, uint256 amount) external onlyOwner nonReentrant {
        require(account != address(0), "Cannot mint to zero address");
        require(amount > 0, "Amount must be positive");

        uint256 newTotalSupply = add(totalSupply, amount);
        require(newTotalSupply > totalSupply, "Mint would overflow supply");

        totalSupply = newTotalSupply;
        balanceOf[account] = add(balanceOf[account], amount);
        emit Transfer(address(0), account, amount);
        emit Mint(account, amount);
    }

    function burn(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be positive");
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");

        balanceOf[msg.sender] = sub(balanceOf[msg.sender], amount);
        totalSupply = sub(totalSupply, amount);
        emit Transfer(msg.sender, address(0), amount);
        emit Burn(msg.sender, amount);
    }

    // Secure Airdrop Implementation
    function airdrop(address[] calldata recipients, uint256[] calldata amounts) external onlyOwner nonReentrant {
        require(recipients.length == amounts.length, "Array length mismatch");
        require(recipients.length > 0 && recipients.length <= 500, "Invalid number of recipients");

        uint256 totalAirdropAmount = 0;
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "Cannot airdrop to zero address");
            require(!_isBlacklisted[recipients[i]], "Recipient blacklisted");
            require(amounts[i] > 0, "Amount must be positive");
            totalAirdropAmount = add(totalAirdropAmount, amounts[i]);
        }

        require(balanceOf[owner] >= totalAirdropAmount, "Insufficient balance");

        balanceOf[owner] = sub(balanceOf[owner], totalAirdropAmount);
        for (uint256 i = 0; i < recipients.length; i++) {
            balanceOf[recipients[i]] = add(balanceOf[recipients[i]], amounts[i]);
            emit Transfer(owner, recipients[i], amounts[i]);
        }
        emit Airdrop(recipients, amounts);
    }

    // Core Transfer Logic (Simplified - No Max Transaction Checks)
    function _transfer(address sender, address recipient, uint256 amount) internal nonReentrant {
        require(sender != address(0), "Transfer from zero address");
        require(recipient != address(0), "Transfer to zero address");
        require(!_isBlacklisted[sender], "Sender blacklisted");
        require(!_isBlacklisted[recipient], "Recipient blacklisted");
        require(amount > 0, "Amount must be positive");
        require(balanceOf[sender] >= amount, "Insufficient balance");

        if (_paused) {
            revert("Transfers paused");
        }

        uint256 taxAmount = 0;
        if (!_excludedFromFees[sender] && !_excludedFromFees[recipient]) {
            if (sender == owner) {
                taxAmount = div(mul(amount, buyTax), 100);
            } else if (recipient == owner) {
                taxAmount = div(mul(amount, sellTax), 100);
            }
        }

        uint256 amountAfterTax = sub(amount, taxAmount);
        require(amountAfterTax <= amount, "Invalid tax calculation");

        // Only max wallet limit check remains
        require(
            add(balanceOf[recipient], amountAfterTax) <= maxWalletLimit,
            "Exceeds max wallet limit"
        );

        balanceOf[sender] = sub(balanceOf[sender], amount);
        balanceOf[recipient] = add(balanceOf[recipient], amountAfterTax);

        if (taxAmount > 0) {
            balanceOf[owner] = add(balanceOf[owner], taxAmount);
            emit Transfer(sender, owner, taxAmount);
        }

        emit Transfer(sender, recipient, amountAfterTax);
    }

    // View Functions
    function isBlacklisted(address account) external view returns (bool) {
        return _isBlacklisted[account];
    }

    function isExcludedFromFees(address account) external view returns (bool) {
        return _excludedFromFees[account];
    }

    // ERC20 Functions with Enhanced Security
    function transfer(address recipient, uint256 amount) external returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        require(amount > 0, "Amount must be positive");
        uint256 currentAllowance = allowance[sender][msg.sender];
        require(currentAllowance >= amount, "Allowance exceeded");

        allowance[sender][msg.sender] = sub(currentAllowance, amount);
        _transfer(sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        require(spender != address(0), "Approve to zero address");
        require(amount > 0 || allowance[msg.sender][spender] == 0, "Invalid approval");

        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    // Ownership Management with Security
    function transferOwnership(address newOwner) external onlyOwner nonReentrant {
        require(newOwner != address(0), "New owner cannot be zero");
        require(newOwner != owner, "Already owner");
        require(!_isBlacklisted[newOwner], "New owner blacklisted");

        address oldOwner = owner;
        owner = newOwner;

        _excludedFromFees[oldOwner] = false;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function renounceOwnership() external onlyOwner nonReentrant {
        address oldOwner = owner;
        owner = address(0);

        _excludedFromFees[oldOwner] = false;
        emit OwnershipTransferred(oldOwner, address(0));
    }

    // Pausable Functions
    function paused() public view returns (bool) {
        return _paused;
    }

    function pause() external onlyOwner {
        _paused = true;
        emit TransferPaused(true);
    }

    function unpause() external onlyOwner {
        _paused = false;
        emit TransferPaused(false);
    }

    // Secure Burn From
    function burnFrom(address account, uint256 amount) external nonReentrant {
        require(account != address(0), "Burn from zero address");
        require(amount > 0, "Amount must be positive");
        require(balanceOf[account] >= amount, "Insufficient balance");

        uint256 currentAllowance = allowance[account][msg.sender];
        require(currentAllowance >= amount, "Allowance exceeded");

        allowance[account][msg.sender] = sub(currentAllowance, amount);
        balanceOf[account] = sub(balanceOf[account], amount);
        totalSupply = sub(totalSupply, amount);
        emit Transfer(account, address(0), amount);
        emit Burn(account, amount);
    }

    // Secure Funds Recovery
    function recoverFunds(address token, uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "Amount must be positive");

        if (token == address(0)) {
            (bool success, ) = payable(owner).call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            require(token != address(this), "Cannot recover native token");

            // Check if the contract actually is a contract
            uint32 size;
            assembly {
                size := extcodesize(token)
            }
            require(size > 0, "Target is not a contract");

            // Safe transfer using low-level call
            (bool success, bytes memory data) = token.call(
                abi.encodeWithSelector(0xa9059cbb, owner, amount)
            );

            require(success, "Token transfer failed");
            if (data.length > 0) {
                require(abi.decode(data, (bool)), "Transfer failed");
            }
        }

        emit FundsRecovered(token, owner, amount);
    }

    // Contract Description
    function description() external pure returns (string memory) {
        return "$IND is an incentive token rewarding USDI holders and users, facilitating ecosystem growth and participation.";
    }

    // Explicit ETH Rejection
    receive() external payable {
        revert("ETH not accepted");
    }

    fallback() external payable {
        revert("Invalid call");
    }
}
