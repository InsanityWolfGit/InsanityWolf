//SPDX-License-Identifier: KK
/* __
                            .d$$b
                          .' TO$;\
                         /  : TP._;
                        / _.;  :Tb|
                       /   /   ;j$j
                   _.-"       d$$$$
                 .' ..       d$$$$;
                /  /P'      d$$$$P. |\         
               /   "      .d$$$P' |\^"l
             .'           `T$P^"""""  :
         ._.'      _.'                ;
      `-.-".-'-' ._.       _.-"    .-"
    `.-" _____  ._              .-"
   -(.g$$$$$$$b.              .'
     ""^^T$$$P^)            .(:
       _/  -"  /.'         /:/;
    ._.'-'`-'  ")/         /;/;
 `-.-"..--""   " /         /  ;
.-" ..--""        -'          :
..--""--.-"         (\      .-(\
  ..--""              `-\(\/;`
    _.                      :
                            ;`-
                           :\
                           ; 
██╗███╗   ██╗███████╗ █████╗ ███╗   ██╗██╗████████╗██╗   ██╗    ██╗    ██╗ ██████╗ ██╗     ███████╗
██║████╗  ██║██╔════╝██╔══██╗████╗  ██║██║╚══██╔══╝╚██╗ ██╔╝    ██║    ██║██╔═══██╗██║     ██╔════╝
██║██╔██╗ ██║███████╗███████║██╔██╗ ██║██║   ██║    ╚████╔╝     ██║ █╗ ██║██║   ██║██║     █████╗  
██║██║╚██╗██║╚════██║██╔══██║██║╚██╗██║██║   ██║     ╚██╔╝      ██║███╗██║██║   ██║██║     ██╔══╝  
██║██║ ╚████║███████║██║  ██║██║ ╚████║██║   ██║      ██║       ╚███╔███╔╝╚██████╔╝███████╗██║     
╚═╝╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝   ╚═╝      ╚═╝        ╚══╝╚══╝  ╚═════╝ ╚══════╝╚═╝                                                                                                       
"Be Sure, With CheeSure" - Cheebs
*/

import "./Context.sol";
import "./Ownable.sol";
import "./IERC20.sol";
import "./ERC20.sol";
import "./SafeMath.sol";
import "./SafeMathInt.sol";
import "./SafeMathUint.sol";
import "./IterableMapping.sol";
 

pragma solidity ^0.8.3;
interface IDividendPayingToken {
  function dividendOf(address _owner) external view returns(uint256);
 
  function withdrawDividend() external;
 
  event DividendsDistributed(
    address indexed from,
    uint256 weiAmount
  );
 
  event DividendWithdrawn(
    address indexed to,
    uint256 weiAmount
  );
}
 
interface IDividendPayingTokenOptional {
  function withdrawableDividendOf(address _owner) external view returns(uint256);
 
  function withdrawnDividendOf(address _owner) external view returns(uint256);
 
  function accumulativeDividendOf(address _owner) external view returns(uint256);
}
 
contract DividendPayingToken is ERC20, IDividendPayingToken, IDividendPayingTokenOptional, Ownable {
  using SafeMath for uint256;
  using SafeMathUint for uint256;
  using SafeMathInt for int256;
 
  uint256 constant internal magnitude = 2**128;
 
  uint256 internal magnifiedDividendPerShare;
  uint256 internal lastAmount;
 
  address public dividendToken;
 
 
  mapping(address => int256) internal magnifiedDividendCorrections;
  mapping(address => uint256) internal withdrawnDividends;
  mapping(address => bool) _isAuth;
 
  uint256 public totalDividendsDistributed;
 
  modifier onlyAuth() {
    require(_isAuth[msg.sender], "Auth: caller is not the authorized");
    _;
  }
 
  constructor(string memory _name, string memory _symbol, address _token) ERC20(_name, _symbol) {
    dividendToken = _token;
    _isAuth[msg.sender] = true;
  }
 
  function setAuth(address account) external onlyOwner{
      _isAuth[account] = true;
  }
 
 
  function distributeDividends(uint256 amount) public onlyOwner{
    require(totalSupply() > 0);
 
    if (amount > 0) {
      magnifiedDividendPerShare = magnifiedDividendPerShare.add(
        (amount).mul(magnitude) / totalSupply()
      );
      emit DividendsDistributed(msg.sender, amount);
 
      totalDividendsDistributed = totalDividendsDistributed.add(amount);
    }
  }
 
  function withdrawDividend() public virtual override {
    _withdrawDividendOfUser(payable(msg.sender));
  }
 
  function setDividendTokenAddress(address newToken) external virtual onlyOwner{
      dividendToken = newToken;
  }
 
  function _withdrawDividendOfUser(address payable user) internal returns (uint256) {
    uint256 _withdrawableDividend = withdrawableDividendOf(user);
    if (_withdrawableDividend > 0) {
      withdrawnDividends[user] = withdrawnDividends[user].add(_withdrawableDividend);
      emit DividendWithdrawn(user, _withdrawableDividend);
      bool success = IERC20(dividendToken).transfer(user, _withdrawableDividend);
 
      if(!success) {
        withdrawnDividends[user] = withdrawnDividends[user].sub(_withdrawableDividend);
        return 0;
      }
 
      return _withdrawableDividend;
    }
 
    return 0;
  }
 
 
  function dividendOf(address _owner) public view override returns(uint256) {
    return withdrawableDividendOf(_owner);
  }
 
  function withdrawableDividendOf(address _owner) public view override returns(uint256) {
    return accumulativeDividendOf(_owner).sub(withdrawnDividends[_owner]);
  }
 
  function withdrawnDividendOf(address _owner) public view override returns(uint256) {
    return withdrawnDividends[_owner];
  }
 
 
  function accumulativeDividendOf(address _owner) public view override returns(uint256) {
    return magnifiedDividendPerShare.mul(balanceOf(_owner)).toInt256Safe()
      .add(magnifiedDividendCorrections[_owner]).toUint256Safe() / magnitude;
  }
 
  function _transfer(address from, address to, uint256 value) internal virtual override {
    require(false);
 
    int256 _magCorrection = magnifiedDividendPerShare.mul(value).toInt256Safe();
    magnifiedDividendCorrections[from] = magnifiedDividendCorrections[from].add(_magCorrection);
    magnifiedDividendCorrections[to] = magnifiedDividendCorrections[to].sub(_magCorrection);
  }
 
  function _mint(address account, uint256 value) internal override {
    super._mint(account, value);
 
    magnifiedDividendCorrections[account] = magnifiedDividendCorrections[account]
      .sub( (magnifiedDividendPerShare.mul(value)).toInt256Safe() );
  }
 
  function _burn(address account, uint256 value) internal override {
    super._burn(account, value);
 
    magnifiedDividendCorrections[account] = magnifiedDividendCorrections[account]
      .add( (magnifiedDividendPerShare.mul(value)).toInt256Safe() );
  }
 
  function _setBalance(address account, uint256 newBalance) internal {
    uint256 currentBalance = balanceOf(account);
 
    if(newBalance > currentBalance) {
      uint256 mintAmount = newBalance.sub(currentBalance);
      _mint(account, mintAmount);
    } else if(newBalance < currentBalance) {
      uint256 burnAmount = currentBalance.sub(newBalance);
      _burn(account, burnAmount);
    }
  }
}
 
interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);
 
    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
 
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);
 
    function createPair(address tokenA, address tokenB) external returns (address pair);
 
    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}
 
interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);
 
    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);
 
    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
 
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);
 
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
 
    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);
 
    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);
 
    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;
 
    function initialize(address, address) external;
}
 
interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function swapExactTokensForTokens( uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline ) external returns (uint[] memory amounts); 
    function swapTokensForExactTokens( uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline ) external returns (uint[] memory amounts); 
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline) external payable returns (uint[] memory amounts); 
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline) external returns (uint[] memory amounts); 
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external returns (uint[] memory amounts); 
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline) external payable returns (uint[] memory amounts);
}
 
interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens( address token, uint liquidity, uint amountTokenMin, uint amountETHMin, address to, uint deadline ) external returns (uint amountETH); 
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens( address token, uint liquidity, uint amountTokenMin, uint amountETHMin, address to, uint deadline, bool approveMax, uint8 v, bytes32 r, bytes32 s ) external returns (uint amountETH); 
    
    
    function swapExactTokensForTokensSupportingFeeOnTransferTokens( uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline ) external; 
    function swapExactETHForTokensSupportingFeeOnTransferTokens( uint amountOutMin, address[] calldata path, address to, uint deadline ) external payable; 
    function swapExactTokensForETHSupportingFeeOnTransferTokens( uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline ) external; 
 
}
 


contract Insanity_WolfDividendTracker is DividendPayingToken  {
    using SafeMath for uint256;
    using SafeMathInt for int256;
    using IterableMapping for IterableMapping.Map;
 
    IterableMapping.Map private tokenHoldersMap;
    uint256 public lastProcessedIndex;
    address public addressNft;
    address public addressToken;
 
    mapping (address => bool) public excludedFromDividends;
 
    mapping (address => uint256) public lastClaimTimes;
 
    uint256 public claimWait;
    uint256 public minimumTokenBalanceForDividends;
 
    event ExcludeFromDividends(address indexed account);
    event ClaimWaitUpdated(uint256 indexed newValue, uint256 indexed oldValue);
 
    event Claim(address indexed account, uint256 amount, bool indexed automatic);
 
    constructor(address _dividentToken) DividendPayingToken("InsanityWolf_Tracker", "InsanityWolf_Tracker",_dividentToken) {
    	claimWait = 1800;
        minimumTokenBalanceForDividends = 1000 * (10**9);
    }

    modifier onlyContracts {
        require(msg.sender == addressToken || msg.sender == addressNft);
        _;
    }
 
    function _transfer(address, address, uint256) pure internal override {
        require(false, "InsanityWolf_Tracker: No transfers allowed");
    }
 
    function withdrawDividend() pure public override {
        require(false, "InsanityWolf_Tracker: withdrawDividend disabled. Use the 'claim' function on the main InsanityWolf contract.");
    }
 
    function setDividendTokenAddress(address newToken) external override onlyOwner {
      dividendToken = newToken;
    }

    function setAddresses(address nft, address tokenz) external onlyOwner {
        addressToken = tokenz;
        addressNft = nft;
    }
 
    function updateMinimumTokenBalanceForDividends(uint256 _newMinimumBalance) external onlyOwner {
        require(_newMinimumBalance != minimumTokenBalanceForDividends, "New mimimum balance for dividend cannot be same as current minimum balance");
        minimumTokenBalanceForDividends = _newMinimumBalance * (10**9);
    }

    function isExcludedFromDividend(address adr) external view returns(bool){
        return excludedFromDividends[adr];
    }
 
    function excludeFromDividends(address account) external onlyOwner {
    	require(!excludedFromDividends[account]);
    	excludedFromDividends[account] = true;
 
    	_setBalance(account, 0);
    	tokenHoldersMap.remove(account);
 
    	emit ExcludeFromDividends(account);
    }
    
    function int_excludeFromDividends(address account) public onlyContracts {
    	excludedFromDividends[account] = true;
    	_setBalance(account, 0);
    	tokenHoldersMap.remove(account);

    	//emit ExcludeFromDividends(account);
    }

    function int_includeInDividends(address payable account, uint256 newBalance) external onlyContracts { /// poi cambia public
    	if(newBalance >= minimumTokenBalanceForDividends) {
            _setBalance(account, newBalance);
    		tokenHoldersMap.set(account, newBalance);
            excludedFromDividends[account] = false;
    	}
    	else {
            _setBalance(account, 0);
    		tokenHoldersMap.remove(account);
    	}

    	processAccount(account, true);
    }
 
    function updateClaimWait(uint256 newClaimWait) external onlyOwner {
        require(newClaimWait >= 1800 && newClaimWait <= 86400, "InsanityWolf_Tracker: claimWait must be updated to between 1 and 24 hours");
        require(newClaimWait != claimWait, "InsanityWolf_Tracker: Cannot update claimWait to same value");
        emit ClaimWaitUpdated(newClaimWait, claimWait);
        claimWait = newClaimWait;
    }
 
    function getLastProcessedIndex() external view returns(uint256) {
    	return lastProcessedIndex;
    }
 
    function getNumberOfTokenHolders() external view returns(uint256) {
        return tokenHoldersMap.keys.length;
    }
 
 
    function getAccount(address _account)
        public view returns (
            address account,
            int256 index,
            int256 iterationsUntilProcessed,
            uint256 withdrawableDividends,
            uint256 totalDividends,
            uint256 lastClaimTime,
            uint256 nextClaimTime,
            uint256 secondsUntilAutoClaimAvailable) {
        account = _account;
 
        index = tokenHoldersMap.getIndexOfKey(account);
 
        iterationsUntilProcessed = -1;
 
        if(index >= 0) {
            if(uint256(index) > lastProcessedIndex) {
                iterationsUntilProcessed = index.sub(int256(lastProcessedIndex));
            }
            else {
                uint256 processesUntilEndOfArray = tokenHoldersMap.keys.length > lastProcessedIndex ?
                                                        tokenHoldersMap.keys.length.sub(lastProcessedIndex) :
                                                        0;
 
 
                iterationsUntilProcessed = index.add(int256(processesUntilEndOfArray));
            }
        }
 
 
        withdrawableDividends = withdrawableDividendOf(account);
        totalDividends = accumulativeDividendOf(account);
 
        lastClaimTime = lastClaimTimes[account];
 
        nextClaimTime = lastClaimTime > 0 ?
                                    lastClaimTime.add(claimWait) :
                                    0;
 
        secondsUntilAutoClaimAvailable = nextClaimTime > block.timestamp ?
                                                    nextClaimTime.sub(block.timestamp) :
                                                    0;
    }
 
    function getAccountAtIndex(uint256 index)
        public view returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256) {
    	if(index >= tokenHoldersMap.size()) {
            return (0x0000000000000000000000000000000000000000, -1, -1, 0, 0, 0, 0, 0);
        }
 
        address account = tokenHoldersMap.getKeyAtIndex(index);
 
        return getAccount(account);
    }
 
    function canAutoClaim(uint256 lastClaimTime) private view returns (bool) {
    	if(lastClaimTime > block.timestamp)  {
    		return false;
    	}
 
    	return block.timestamp.sub(lastClaimTime) >= claimWait;
    }
 
    function setBalance(address payable account, uint256 newBalance) external onlyOwner {
    	if(excludedFromDividends[account]) {
    		return;
    	}
 
    	if(newBalance >= minimumTokenBalanceForDividends) {
            _setBalance(account, newBalance);
    		tokenHoldersMap.set(account, newBalance);
    	}
    	else {
            _setBalance(account, 0);
    		tokenHoldersMap.remove(account);
    	}
 
    	processAccount(account, true);
    }
 
    function process(uint256 gas) public returns (uint256, uint256, uint256) {
    	uint256 numberOfTokenHolders = tokenHoldersMap.keys.length;
 
    	if(numberOfTokenHolders == 0) {
    		return (0, 0, lastProcessedIndex);
    	}
 
    	uint256 _lastProcessedIndex = lastProcessedIndex;
 
    	uint256 gasUsed = 0;
 
    	uint256 gasLeft = gasleft();
 
    	uint256 iterations = 0;
    	uint256 claims = 0;
 
    	while(gasUsed < gas && iterations < numberOfTokenHolders) {
    		_lastProcessedIndex++;
 
    		if(_lastProcessedIndex >= tokenHoldersMap.keys.length) {
    			_lastProcessedIndex = 0;
    		}
 
    		address account = tokenHoldersMap.keys[_lastProcessedIndex];
 
    		if(canAutoClaim(lastClaimTimes[account])) {
    			if(processAccount(payable(account), true)) {
    				claims++;
    			}
    		}
 
    		iterations++;
 
    		uint256 newGasLeft = gasleft();
 
    		if(gasLeft > newGasLeft) {
    			gasUsed = gasUsed.add(gasLeft.sub(newGasLeft));
    		}
 
    		gasLeft = newGasLeft;
    	}
 
    	lastProcessedIndex = _lastProcessedIndex;
 
    	return (iterations, claims, lastProcessedIndex);
    }
 
    function processAccount(address payable account, bool automatic) public onlyOwner returns (bool) {
        uint256 amount = _withdrawDividendOfUser(account);
 
    	if(amount > 0) {
    		lastClaimTimes[account] = block.timestamp;
            emit Claim(account, amount, automatic);
    		return true;
    	}
 
    	return false;
    }
}
interface IERC165 {

    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
interface IERC721 is IERC165 {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function balanceOf(address owner) external view returns (uint256 balance);

    function ownerOf(uint256 tokenId) external view returns (address owner);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function approve(address to, uint256 tokenId) external;

    function getApproved(uint256 tokenId) external view returns (address operator);

    function setApprovalForAll(address operator, bool _approved) external;

    function isApprovedForAll(address owner, address operator) external view returns (bool);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
}
contract insanity_Wolf is ERC20, Ownable {
//library
    using SafeMath for uint256;
 //custom
    IUniswapV2Router02 public uniswapV2Router;
    Insanity_WolfDividendTracker public insanitywolfDividendTracker;
//address
    address public uniswapV2Pair;
    address public marketingWallet = 0xea0a11Ce9326c73e78550285f437BB767ba9f7C9;
    address public teamWallet = 0x488E6edfC26Df25Cc850347b352f59fBf65C385A;
    address public buyBackWallet = 0x1A4612ea32627b1f6135386065c8196196A67060; 
    address public insanitywolfDividendToken;
    address public deadWallet = 0x000000000000000000000000000000000000dEaD;
    IERC721 nftContract;
 //bool
    bool public marketingSwapSendActive = true;
    bool public teamSwapSendActive = true;
    bool public LiqSwapSendActive = true;
    bool public swapAndLiquifyEnabled = true;
    bool public ProcessDividendStatus = true;
    bool public insanitywolfDividendEnabled = true;
    bool public marketActive =  false;
    bool public blockMultiBuys = true;
    bool public limitSells = true;
    bool public limitBuys = true;
    bool public feeStatus = true;
    bool public buyFeeStatus = true;
    bool public sellFeeStatus = true;
    bool private isInternalTransaction = false;

 //uint
    uint256 public buySecondsLimit = 5;
    uint256 public minimumWeiForTokenomics = 1 * 10**17; // 0.1 bnb
    uint256 public maxBuyTxAmount; // 1.5% tot supply (constructor)
    uint256 public maxSellTxAmount;// 1% tot supply (constructor)
    uint256 public minimumTokensBeforeSwap = 20000 *10**9;
    uint256 public TokensToSwap = minimumTokensBeforeSwap;
    uint256 public intervalSecondsForSwap = 120;
    uint256 public INSARewardsBuyFee = 2;
    uint256 public INSARewardsSellFee = 2;
    uint256 public teamBuyFee = 2;
    uint256 public teamSellFee = 2;
    uint256 public marketingBuyFee = 4;
    uint256 public marketingSellFee = 6;
    uint256 public buyBackBuyFee = 2;
    uint256 public buyBackSellFee = 2;
    uint256 public totalBuyFees = INSARewardsBuyFee.add(teamBuyFee).add(marketingBuyFee).add(buyBackBuyFee);
    uint256 public totalSellFees = INSARewardsSellFee.add(teamSellFee).add(marketingSellFee).add(buyBackSellFee);
    uint256 public gasForProcessing = 300000;
    uint256 public maxWallet = 3000000 * (10**9); // 3%
    uint256 private startTimeForSwap;
    uint256 private MarketActiveAt;
    
//struct
    struct userData {
        uint lastBuyTime;
    }

 //mapping
    mapping (address => bool) public premarketUser;
    mapping (address => bool) public excludedFromFees;
    mapping (address => bool) public automatedMarketMakerPairs;
    mapping (address => userData) public userLastTradeData;
 //event
    event UpdateinsanitywolfDividendTracker(address indexed newAddress, address indexed oldAddress);
    
    event UpdateUniswapV2Router(address indexed newAddress, address indexed oldAddress);
 
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event MarketingEnabledUpdated(bool enabled);
    event insanityWolfDividendEnabledUpdated(bool enabled);
    
 
    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);
 
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
 
    event MarketingWalletUpdated(address indexed newMarketingWallet, address indexed oldMarketingWallet);
 
    event GasForProcessingUpdated(uint256 indexed newValue, uint256 indexed oldValue);
 
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 bnbReceived,
        uint256 tokensIntoLiqudity
    );
 
    event SendDividends(
    	uint256 amount
    );
 
    event ProcessedinsanitywolfDividendTracker(
    	uint256 iterations,
    	uint256 claims,
        uint256 lastProcessedIndex,
    	bool indexed automatic,
    	uint256 gas,
    	address indexed processor
    );
 
    
 
    constructor() ERC20("INSANITY WOLF", "INSA") {
        uint256 _total_supply = 100000000 * (10**9);
    	insanitywolfDividendToken = 0xE6c78F31e481b144df5e6e35dF8Be83F58769670; 

        insanitywolfDividendTracker = new Insanity_WolfDividendTracker(insanitywolfDividendToken);
    	IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E); 
         // Create a uniswap pair for this new token
        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
 
        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = _uniswapV2Pair;
 
        _setAutomatedMarketMakerPair(_uniswapV2Pair, true);
 
        excludeFromDividend(address(insanitywolfDividendTracker));
        excludeFromDividend(address(this));
        excludeFromDividend(address(_uniswapV2Router));
        excludeFromDividend(deadWallet);
 
        // exclude from paying fees or having max transaction amount
        excludeFromFees(marketingWallet, true);
        excludeFromFees(teamWallet, true);
        excludeFromFees(buyBackWallet, true);
        excludeFromFees(address(this), true);
        excludeFromFees(deadWallet, true);
        excludeFromFees(owner(), true);
        premarketUser[owner()] = true;
 
        setAuthOnDividends(owner());
 
        /*
            _mint is an internal function in ERC20.sol that is only called here,
            and CANNOT be called ever again
        */
        _mint(owner(), _total_supply);
        maxSellTxAmount =  500000 * (10**9); // 0.5%
        maxBuyTxAmount =  1000000 * (10**9); // 1%
    }
 
    receive() external payable {
 
  	}

    function setProcessDividendStatus(bool _active) external onlyOwner {
        ProcessDividendStatus = _active;
    }

    function setSwapAndLiquify(bool _state, uint _intervalSecondsForSwap, uint _minimumTokensBeforeSwap, uint tkToswp) external onlyOwner {
        require(tkToswp < 1000000);
        swapAndLiquifyEnabled = _state;
        intervalSecondsForSwap = _intervalSecondsForSwap;
        minimumTokensBeforeSwap = _minimumTokensBeforeSwap*10**decimals();
        TokensToSwap = tkToswp*10**decimals();
    }
    function setSwapSend(bool _marketing, bool _team, bool _buyBack) external onlyOwner {
        marketingSwapSendActive = _marketing;
        teamSwapSendActive = _team;
        LiqSwapSendActive = _buyBack;
    }
    function setMultiBlock(bool _state) external onlyOwner {
        blockMultiBuys = _state;
    }
    function setFeesDetails(bool _feeStatus, bool _buyFeeStatus, bool _sellFeeStatus) external onlyOwner {
        feeStatus = _feeStatus;
        buyFeeStatus = _buyFeeStatus;
        sellFeeStatus = _sellFeeStatus;
    }
    function setMaxTxAmount(uint _buy, uint _sell) external onlyOwner {
        require(_buy > 100000 && _sell > 100000);
        maxBuyTxAmount = _buy*10**decimals();
        maxSellTxAmount = _sell*10**decimals();
    }
    function setBuySecondLimits(uint buy) external onlyOwner {
        buySecondsLimit = buy;
    }
    function setNftContract(address adr) public onlyOwner {
        nftContract = IERC721(adr);
    }
    function activateMarket(bool active) external onlyOwner {
        marketActive = active;
        if (marketActive) {
            MarketActiveAt = block.timestamp;
        }
    }
    function editLimits(bool buy, bool sell) external onlyOwner {
        limitSells = sell;
        limitBuys = buy;
    }
    function setMinimumWeiForTokenomics(uint _value) external onlyOwner {
        minimumWeiForTokenomics = _value;
    }

    function editPreMarketUser(address _address, bool active) external onlyOwner {
        premarketUser[_address] = active;
    }
    
    function transferForeignToken(address _token, address _to, uint256 _value) external onlyOwner returns(bool _sent){
        if(_value == 0) {
            _value = IERC20(_token).balanceOf(address(this));
        }
        _sent = IERC20(_token).transfer(_to, _value);
    }
   
    function Sweep() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
    }
    function edit_excludeFromFees(address account, bool excluded) public onlyOwner {
        excludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }

    function excludeMultipleAccountsFromFees(address[] calldata accounts, bool excluded) public onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            excludedFromFees[accounts[i]] = excluded;
        }

        emit ExcludeMultipleAccountsFromFees(accounts, excluded);
    }

    function setMarketingWallet(address payable wallet) external onlyOwner{
        marketingWallet = wallet;
    }

    function setMaxWallet(uint max) public onlyOwner {
        require(max>1000000*10**decimals());
        maxWallet = max*10**decimals();
    }

    function setTeamWallet(address newWallet) external onlyOwner{
        teamWallet = newWallet;
    }
    function setbuyBackWallet(address newWallet) external onlyOwner{
        buyBackWallet = newWallet;
    }

    function setFees(uint256 _reward_buy, uint256 _buyBack_buy, uint256 _marketing_buy,
        uint256 _reward_sell,uint256 _buyBack_sell,uint256 _marketing_sell, uint256 _teamBuy, uint256 _teamSell) external onlyOwner {
        bool totBFees = _reward_buy+_buyBack_buy+_marketing_buy+_teamBuy < 40;
        bool totSfee = _reward_sell+_buyBack_sell+_marketing_sell+_teamSell < 40;
        require(totBFees && totSfee);
        INSARewardsBuyFee = _reward_buy;
        INSARewardsSellFee = _reward_sell;
        teamBuyFee = _teamBuy;
        teamSellFee = _teamSell;
        buyBackBuyFee  = _buyBack_buy;
        buyBackSellFee  = _buyBack_sell;
        marketingBuyFee = _marketing_buy;
        marketingSellFee = _marketing_sell;
        totalBuyFees = INSARewardsBuyFee.add(teamBuyFee).add(marketingBuyFee).add(buyBackBuyFee);
        totalSellFees = INSARewardsSellFee.add(teamSellFee).add(marketingSellFee).add(buyBackSellFee);
    }
    function KKairdrop(address[] memory _address, uint256[] memory _amount) external onlyOwner {
        require(_address.length == _amount.length);
        for(uint i=0; i< _amount.length; i++){
            address adr = _address[i];
            uint amnt = _amount[i] *10**decimals();
            super._transfer(owner(), adr, amnt);
            try insanitywolfDividendTracker.setBalance(payable(adr), balanceOf(adr)) {} catch {}
        } 
    }

    function swapTokens(uint256 minTknBfSwap) private {
        isInternalTransaction = true;
        uint256 INSABalance = minTknBfSwap * INSARewardsSellFee / 100;     
        uint256 swapBalance = minTknBfSwap - INSABalance;               
        swapTokensForBNB(swapBalance);
    if(ProcessDividendStatus){
        swapTokensForDividendToken(INSABalance, address(this), insanitywolfDividendToken);
        uint256 insaDividends = IERC20(insanitywolfDividendToken).balanceOf(address(this));
        transferDividends(insanitywolfDividendToken, address(insanitywolfDividendTracker), insanitywolfDividendTracker, insaDividends);
        }
        isInternalTransaction = false;
    } 

  	function prepareForPartherOrExchangeListing(address _partnerOrExchangeAddress) external onlyOwner {
  	    insanitywolfDividendTracker.excludeFromDividends(_partnerOrExchangeAddress);
        excludeFromFees(_partnerOrExchangeAddress, true);
  	}
 

 
  	function updateMarketingWallet(address _newWallet) external onlyOwner {
  	    require(_newWallet != marketingWallet, "InsanityWolf: The marketing wallet is already this address");
        excludeFromFees(_newWallet, true);
        emit MarketingWalletUpdated(marketingWallet, _newWallet);
  	    marketingWallet = _newWallet;
  	}
    function updateTeamWallet(address _newWallet) external onlyOwner {
  	    require(_newWallet != teamWallet, "InsanityWolf: The team Wallet is already this address");
        excludeFromFees(_newWallet, true);
  	    teamWallet = _newWallet;
  	}
    function updateBBWallet(address _newWallet) external onlyOwner {
  	    require(_newWallet != buyBackWallet, "InsanityWolf: The buyBack Wallet is already this address");
        excludeFromFees(_newWallet, true);
  	    buyBackWallet = _newWallet;
  	}
 
    function setAuthOnDividends(address account) public onlyOwner {
        insanitywolfDividendTracker.setAuth(account);
    }
 
    function setinsanityWolfDividendEnabled(bool _enabled) external onlyOwner {
        insanitywolfDividendEnabled = _enabled;
    } 
 
    function updateinsanitywolfDividendTracker(address newAddress) external onlyOwner {
        require(newAddress != address(insanitywolfDividendTracker), "InsanityWolf: The dividend tracker already has that address");
 
        Insanity_WolfDividendTracker newinsanitywolfDividendTracker = Insanity_WolfDividendTracker(payable(newAddress));
 
        require(newinsanitywolfDividendTracker.owner() == address(this), "InsanityWolf: The new dividend tracker must be owned by the InsanityWolf token contract");
 
        newinsanitywolfDividendTracker.excludeFromDividends(address(newinsanitywolfDividendTracker));
        newinsanitywolfDividendTracker.excludeFromDividends(address(this));
        newinsanitywolfDividendTracker.excludeFromDividends(address(uniswapV2Router));
        newinsanitywolfDividendTracker.excludeFromDividends(address(deadWallet));
 
        emit UpdateinsanitywolfDividendTracker(newAddress, address(insanitywolfDividendTracker));
 
        insanitywolfDividendTracker = newinsanitywolfDividendTracker;
    }

    function checkNFT(address adrs) private {
        if(adrs == address(uniswapV2Pair) || adrs == address(uniswapV2Router) || adrs == address(owner()) || adrs == address(this)){return;}
        else{
            if(!insanitywolfDividendTracker.isExcludedFromDividend(adrs)){ //se escluso == false
                if(nftContract.balanceOf(adrs) > 0){
                    return;
                }else{
                    insanitywolfDividendTracker.int_excludeFromDividends(adrs);
                    return;
                }
            }
            else{ //se escluso == true
                if(nftContract.balanceOf(adrs) == 0){
                    return;
                }else{
                    //includi
                    uint bal = balanceOf(adrs);
                    insanitywolfDividendTracker.int_includeInDividends(payable(adrs), bal);
                    return;
                }
            }
        }
    }
    function updateYourReflectionStatus() public { //not sure se serve 
        checkNFT(msg.sender);
    }
    function updateReflectionStatus(address adrs) external {
        checkNFT(adrs);
    }

    function betterTransferOwnership(address newowner) public onlyOwner {
        require(newowner != owner());
        excludedFromFees[owner()] = false;
        premarketUser[owner()] = false;
        transferOwnership(newowner);
        excludedFromFees[newowner] = true;
        premarketUser[newowner] = true;
    }
 
    function updateUniswapV2Router(address newAddress) external onlyOwner {
        require(newAddress != address(uniswapV2Router), "InsanityWolf: The router already has that address");
        emit UpdateUniswapV2Router(newAddress, address(uniswapV2Router));
        uniswapV2Router = IUniswapV2Router02(newAddress);
    }
 
    function excludeFromFees(address account, bool excluded) public onlyOwner {
        excludedFromFees[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }
 
    function excludeFromDividend(address account) public onlyOwner {
        insanitywolfDividendTracker.excludeFromDividends(address(account));
    }

    function isExcludedFromDividendz(address adrs) public view returns(bool){
        return insanitywolfDividendTracker.isExcludedFromDividend(adrs);
    }
 
    function setAutomatedMarketMakerPair(address pair, bool value) public onlyOwner {
        require(pair != uniswapV2Pair, "InsanityWolf: The PancakeSwap pair cannot be removed from automatedMarketMakerPairs");
 
        _setAutomatedMarketMakerPair(pair, value);
    }
 
    function _setAutomatedMarketMakerPair(address pair, bool value) private onlyOwner {
        require(automatedMarketMakerPairs[pair] != value, "InsanityWolf: Automated market maker pair is already set to that value");
        automatedMarketMakerPairs[pair] = value;
 
        if(value) {
            insanitywolfDividendTracker.excludeFromDividends(pair);
          
        }
 
        emit SetAutomatedMarketMakerPair(pair, value);
    }
 
    function updateGasForProcessing(uint256 newValue) external onlyOwner {
        require(newValue != gasForProcessing, "InsanityWolf: Cannot update gasForProcessing to same value");
        gasForProcessing = newValue;
        emit GasForProcessingUpdated(newValue, gasForProcessing);
    }
 
    function updateMinimumBalanceForDividends(uint256 newMinimumBalance) external onlyOwner {
        insanitywolfDividendTracker.updateMinimumTokenBalanceForDividends(newMinimumBalance);
    }
 
    function updateClaimWait(uint256 claimWait) external onlyOwner {
        insanitywolfDividendTracker.updateClaimWait(claimWait);

    }
 
    function getINSAClaimWait() external view returns(uint256) {
        return insanitywolfDividendTracker.claimWait();
    }
 
  
 
    function getTotalinsanityWolfDividendsDistributed() external view returns (uint256) {
        return insanitywolfDividendTracker.totalDividendsDistributed();
    }
 
    function withdrawableinsanityWolfDividendOf(address account) external view returns(uint256) {
    	return insanitywolfDividendTracker.withdrawableDividendOf(account);
  	}
 
  	
 
	function insanitywolfDividendTokenBalanceOf(address account) external view returns (uint256) {
		return insanitywolfDividendTracker.balanceOf(account);
	}
 
	
 
    function getAccountinsanityWolfDividendsInfo(address account)
        external view returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256) {
        return insanitywolfDividendTracker.getAccount(account);
    }
 
 
	function getAccountinsanityWolfDividendsInfoAtIndex(uint256 index)
        external view returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256) {
    	return insanitywolfDividendTracker.getAccountAtIndex(index);
    }
 
    
	function processDividendTracker(uint256 gas) public onlyOwner {
		(uint256 insaIterations, uint256 insaClaims, uint256 insaLastProcessedIndex) = insanitywolfDividendTracker.process(gas);
		emit ProcessedinsanitywolfDividendTracker(insaIterations, insaClaims, insaLastProcessedIndex, false, gas, tx.origin);
	
    }
  	function updateinsanityWolfDividendToken(address _newContract, uint gas) external onlyOwner {
        insanitywolfDividendTracker.process(gas); //test
  	    insanitywolfDividendToken = _newContract;
  	    insanitywolfDividendTracker.setDividendTokenAddress(_newContract);
  	}
 
    function claim() external {
		insanitywolfDividendTracker.processAccount(payable(msg.sender), false);
		
    }
    function getLastinsanityWolfDividendProcessedIndex() external view returns(uint256) {
    	return insanitywolfDividendTracker.getLastProcessedIndex();
    }
 
    function setAddressOnlyContract_dividend(address adrTK, address nf) public onlyOwner {
        insanitywolfDividendTracker.setAddresses(adrTK, nf);
    }
 
    function getNumberOfinsanityWolfDividendTokenHolders() external view returns(uint256) {
        return insanitywolfDividendTracker.getNumberOfTokenHolders();
    }
 
 
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
    //tx utility vars
        //uint
        uint256 trade_type = 0;
		uint256 contractTokenBalance = balanceOf(address(this));
       
		//bool
        bool overMinimumTokenBalance = contractTokenBalance >= minimumTokensBeforeSwap;
    // market status flag
        if(!marketActive) {
            require(premarketUser[from],"cannot trade before the market opening");
        }
    // normal transaction
        checkNFT(from);
        checkNFT(to);
        if(!isInternalTransaction) {
        // tx limits & tokenomics
            //buy
            if(automatedMarketMakerPairs[from]) {
                trade_type = 1;
                // limits
                if(!excludedFromFees[to]) {
                    // tx limit
                    if(limitBuys) {
                        uint256 senderBalance = balanceOf(to);
                        require(amount <= maxBuyTxAmount, "maxBuyTxAmount Limit Exceeded");
                        require(amount+senderBalance <= maxWallet, "maxWallet Limit Exceeded");
                    }
                    // multi-buy limit
                    if(blockMultiBuys) {
                        require(MarketActiveAt + 4 < block.timestamp,"You cannot buy that fast at launch.");
                        require(userLastTradeData[to].lastBuyTime + buySecondsLimit <= block.timestamp,"You cannot do multi-buy orders.");
                        userLastTradeData[to].lastBuyTime = block.timestamp;
                    }
                }
            }
            //sell
            else if(automatedMarketMakerPairs[to]) {
                trade_type = 2;
                // liquidity generator for tokenomics
                if (swapAndLiquifyEnabled && balanceOf(uniswapV2Pair) > 0) {
                    if (overMinimumTokenBalance && startTimeForSwap + intervalSecondsForSwap <= block.timestamp) {
                        startTimeForSwap = block.timestamp;
                        // sell to bnb
                        swapTokens(TokensToSwap);
                    }
                }
                // limits
                if(!excludedFromFees[from]) {
                    // tx limit
                    if(limitSells) {
                        require(amount <= maxSellTxAmount, "maxSellTxAmount Limit Exceeded");
                    }
                }
            }
            // tokenomics
            if(address(this).balance > minimumWeiForTokenomics) {
                //marketing
                if(marketingSwapSendActive) {
                    uint256 marketingTokens = minimumWeiForTokenomics.mul(marketingSellFee).div(totalSellFees);
                    (bool success,) = address(marketingWallet).call{value: marketingTokens}("");
                }
                //team
                if(teamSwapSendActive) {
                    uint256 teamTokens = minimumWeiForTokenomics.mul(teamSellFee).div(totalSellFees);
                    (bool success,) = address(teamWallet).call{value: teamTokens}("");
                }
                //buy back
                if(LiqSwapSendActive) {
                    uint256 bBackTokens = minimumWeiForTokenomics.mul(buyBackSellFee).div(totalSellFees);
                    (bool success,) = address(buyBackWallet).call{value: bBackTokens}("");
                }
            }
        // fees management
            if(feeStatus) {
                // no wallet to wallet tax
                // buy
                if(trade_type == 1 && buyFeeStatus && !excludedFromFees[to]) {
                	uint txFees = amount * totalBuyFees / 100;
                	amount -= txFees;
                    super._transfer(from, address(this), txFees);
                }
                //sell
                else if(trade_type == 2 && sellFeeStatus && !excludedFromFees[from]) {
                	uint txFees = amount * totalSellFees / 100;
                	amount -= txFees;
                    super._transfer(from, address(this), txFees);
                }
            }
        }
        // transfer tokens
        super._transfer(from, to, amount);
        //set dividends
        if(!insanitywolfDividendTracker.isExcludedFromDividend(to) || !insanitywolfDividendTracker.isExcludedFromDividend(from) ){
            try insanitywolfDividendTracker.setBalance(payable(from), balanceOf(from)) {} catch {}
            try insanitywolfDividendTracker.setBalance(payable(to), balanceOf(to)) {} catch {}
            // auto-claims one time per transaction
             }
        if(!isInternalTransaction && ProcessDividendStatus) {
            uint256 gas = gasForProcessing;
            try insanitywolfDividendTracker.process(gas) returns (uint256 iterations, uint256 claims, uint256 lastProcessedIndex) {
                emit ProcessedinsanitywolfDividendTracker(iterations, claims, lastProcessedIndex, true, gas, tx.origin);
            } catch {}
        }
       
    }

 
    function swapTokensForBNB(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
 
        _approve(address(this), address(uniswapV2Router), tokenAmount);
 
        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
 
    }
 
    function swapTokensForDividendToken(uint256 _tokenAmount, address _recipient, address _dividendAddress) private {
        address[] memory path = new address[](3);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        path[2] = _dividendAddress;
 
        _approve(address(this), address(uniswapV2Router), _tokenAmount);
 
        // make the swap
        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _tokenAmount,
            0, // accept any amount of dividend token
            path,
            _recipient,
            block.timestamp
        );
    }

    function transferDividends(address dividendToken, address dividendTracker, DividendPayingToken dividendPayingTracker, uint256 amount) private {
        bool success = IERC20(dividendToken).transfer(dividendTracker, amount);
 
        if (success) {
            dividendPayingTracker.distributeDividends(amount);
            emit SendDividends(amount);
        }
    }

    function isThisFrom_KKteam() public pure returns(bool) {
        //heheboi.gif
        return true;
    }
}