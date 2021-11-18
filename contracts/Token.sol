// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

contract Token is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    event TokenBurn(address indexed from, uint256 value);
    event CollectedFees();
    event SetLiquidityFee(uint256 amount);
    event SetMarketingFee(uint256 amount);
    event SetBurnFee(uint256 amount);

    string private _name = "OG Shiba";
    string private _symbol = "OGSHIB";
    uint8 private _decimals = 18;
    uint256 private _totalSupply = 100000 * 10**9 * 10**_decimals;

    address payable public marketingAddress = payable(0xe21534C9751F17b6B245576DB9CEb7f4eaE91396);
    address public marketingWalletToken = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address public constant deadAddress = 0x000000000000000000000000000000000000dEaD;

    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) private _isExcludedFromFees;
    mapping (address => bool) private _isExcludedFromMaxBalance;

    uint256 private constant _maxFees = 10;
    uint256 private _totalFees;
    uint256 private _totalFeesToContract;
    uint256 private _liquidityFee;
    uint256 private _burnFee;
    uint256 private _marketingFee;

    uint256 private _maxBalance;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    uint256 private _liquifyThreshhold;
    bool inSwapAndLiquify;

    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    constructor () {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
        .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;

        _isExcludedFromFees[owner()] = true;
        _isExcludedFromFees[address(this)] = true;

        _isExcludedFromMaxBalance[owner()] = true;
        _isExcludedFromMaxBalance[address(this)] = true;
        _isExcludedFromMaxBalance[uniswapV2Pair] = true;

        _liquidityFee = 5;
        _marketingFee = 4;
        _burnFee = 1;
        _totalFees = _liquidityFee.add(_marketingFee).add(_burnFee);
        _totalFeesToContract = _liquidityFee.add(_marketingFee);

        _liquifyThreshhold = 20 * 10**9 * 10**_decimals;
        _maxBalance = 500 * 10**9 * 10**_decimals;

        _balances[_msgSender()] = _totalSupply;
        emit Transfer(address(0), _msgSender(), _totalSupply);
    }

    receive() external payable {}

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function setMarketingAddress(address payable newMarketingAddress) external onlyOwner() {
        marketingAddress = newMarketingAddress;
    }

    function setLiquidityFeePercent(uint256 newLiquidityFee) external onlyOwner() {
        require(!inSwapAndLiquify, "inSwapAndLiquify");
        require(newLiquidityFee.add(_burnFee).add(_marketingFee) <= _maxFees, "Fees are too high.");
        _liquidityFee = newLiquidityFee;
        _totalFees = _liquidityFee.add(_marketingFee).add(_burnFee);
        _totalFeesToContract = _liquidityFee.add(_marketingFee);
        emit SetLiquidityFee(_liquidityFee);
    }

    function setMarketingFeePercent(uint256 newMarketingFee) external onlyOwner() {
        require(!inSwapAndLiquify, "inSwapAndLiquify");
        require(_liquidityFee.add(_burnFee).add(newMarketingFee) <= _maxFees, "Fees are too high.");
        _marketingFee = newMarketingFee;
        _totalFees = _liquidityFee.add(_marketingFee).add(_burnFee);
        _totalFeesToContract = _liquidityFee.add(_marketingFee);
        emit SetMarketingFee(_marketingFee);
    }

    function setBurnFeePercent(uint256 newBurnFee) external onlyOwner() {
        require(_liquidityFee.add(newBurnFee).add(_marketingFee) <= _maxFees, "Fees are too high.");
        _burnFee = newBurnFee;
        _totalFees = _liquidityFee.add(_marketingFee).add(_burnFee);
        emit SetBurnFee(_burnFee);
    }

    function setLiquifyThreshhold(uint256 newLiquifyThreshhold) external onlyOwner() {
        _liquifyThreshhold = newLiquifyThreshhold;
    }

    function setMarketingWalletToken(address _marketingWalletToken) external onlyOwner(){
        marketingWalletToken = _marketingWalletToken;
    }

    function setMaxBalance(uint256 newMaxBalance) external onlyOwner(){
        // Minimum _maxBalance is 0.5% of _totalSupply
        require(newMaxBalance >= _totalSupply.mul(5).div(1000));
        _maxBalance = newMaxBalance;
    }

    function isExcludedFromFees(address account) public view returns(bool) {
        return _isExcludedFromFees[account];
    }

    function excludeFromFees(address account) public onlyOwner {
        _isExcludedFromFees[account] = true;
    }

    function includeInFees(address account) public onlyOwner {
        _isExcludedFromFees[account] = false;
    }

    function isExcludedFromMaxBalance(address account) public view returns(bool) {
        return _isExcludedFromMaxBalance[account];
    }

    function excludeFromMaxBalance(address account) public onlyOwner {
        _isExcludedFromMaxBalance[account] = true;
    }

    function includeInMaxBalance(address account) public onlyOwner {
        _isExcludedFromMaxBalance[account] = false;
    }

    function totalFees() public view returns (uint256) {
        return _totalFees;
    }

    function liquidityFee() public view returns (uint256) {
        return _liquidityFee;
    }

    function marketingFee() public view returns (uint256) {
        return _marketingFee;
    }

    function burnFee() public view returns (uint256) {
        return _burnFee;
    }

    function maxFees() public pure returns (uint256) {
        return _maxFees;
    }

    function liquifyThreshhold() public view returns(uint256){
        return _liquifyThreshhold;
    }

    function maxBalance() public view returns (uint256) {
        return _maxBalance;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        // Make sure that: Balance + Buy Amount <= _maxBalance
        if(
            from != owner() &&              // Not from Owner
            to != owner() &&                // Not to Owner
            !_isExcludedFromMaxBalance[to]  // is excludedFromMaxBalance
        ){
            require(
                balanceOf(to).add(amount) <= _maxBalance,
                "Max Balance is reached."
            );
        }

        // Swap Fees
        if(
            to == uniswapV2Pair &&                              // Sell
            !inSwapAndLiquify &&                                // Swap is not locked
            balanceOf(address(this)) >= _liquifyThreshhold &&   // liquifyThreshhold is reached
            _totalFeesToContract > 0 &&                         // LiquidityFee + MarketingFee > 0
            from != owner() &&                                  // Not from Owner
            to != owner()                                       // Not to Owner
        ) {
            collectFees();
            emit CollectedFees();
        }

        // Take Fees
        if(
            !(_isExcludedFromFees[from] || _isExcludedFromFees[to])
            && _totalFees > 0
        ) {

        	uint256 feesToContract = amount.mul(_totalFeesToContract).div(100);
            uint256 toBurnAmount = amount.mul(_burnFee).div(100);

        	amount = amount.sub(feesToContract.add(toBurnAmount));

            transferToken(from, address(this), feesToContract);
            transferToken(from, deadAddress, toBurnAmount);
            emit TokenBurn(from, toBurnAmount);
        }

        transferToken(from, to, amount);
    }

    function collectFees() private lockTheSwap {

        uint256 liquidityTokensToSell = balanceOf(address(this)).mul(_liquidityFee).div(_totalFeesToContract);
        uint256 marketingTokensToSell = balanceOf(address(this)).mul(_marketingFee).div(_totalFeesToContract);

        // Get collected Liquidity Fees
        swapAndLiquify(liquidityTokensToSell);

        // Get collected Marketing Fees
        swapAndSendToFee(marketingTokensToSell);
    }

    function swapAndLiquify(uint256 tokens) private {

        uint256 half = tokens.div(2);
        uint256 otherHalf = tokens.sub(half);

        // current ETH balance
        uint256 initialBalance = address(this).balance;

        swapTokensForEth(half);

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        addLiquidity(otherHalf, newBalance);
    }

    function swapAndSendToFee(uint256 tokens) private  {

        swapTokensForMarketingToken(tokens);

        // Transfer sold Token to marketingWallet
        IERC20(marketingWalletToken).transfer(marketingAddress, IERC20(marketingWalletToken).balanceOf(address(this)));
    }

    function swapTokensForEth(uint256 tokenAmount) private {

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function swapTokensForMarketingToken(uint256 tokenAmount) private {

        address[] memory path = new address[](3);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        path[2] = marketingWalletToken;

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            address(0),
            block.timestamp
        );
    }

    function transferToken(address sender, address recipient, uint256 amount) private {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }
}