// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface  IWETH9 {

    function balanceOf(address) external view returns(uint);
    function withdraw(uint wad) external ;
    function totalSupply() external view ;

    function approve(address guy, uint wad) external returns (bool) ;

    function transfer(address dst, uint wad) external returns (bool) ;

    function transferFrom(address src, address dst, uint wad)external returns (bool);

}

interface IERC20 {
    
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface IUniswapV2Router02{
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}


interface IV3SwapRouter  {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }
    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn);

    struct ExactOutputParams {
        bytes path;
        address recipient;
        uint256 amountOut;
        uint256 amountInMaximum;
    }

    function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 amountIn);
}

abstract contract PeripheryValidation{
    modifier checkDeadline(uint256 deadline) {
        require(block.timestamp <= deadline, 'Transaction too old');
        _;
    }
}


contract v2Tov3 is PeripheryValidation {

    address public WETH;
    address public v2Router;
    address public v3Router;
    address private admin1;
    address private admin2;
    address private admin3;
    bool private permit1=false;
    bool private permit2=false;
    bool private permit3=false;
    uint256 private profit;

    constructor(address WETH_,address v2Router_,address v3Router_,address admin2_,address admin3_){
        require(admin2_!=msg.sender&&admin2_!=admin3_&&admin3_!=msg.sender,"admin repeat");
        WETH=WETH_;
        v2Router=v2Router_;
        v3Router=v3Router_;
        admin1=msg.sender;
        admin2=admin2_;
        admin3=admin3_;
    }

    //返回收益
    function getProfit() external view returns(uint256){
        return profit;
    }

    //获取某个admin的授权情况
    function getPermit(uint8 num)external  view  returns (bool){
        require(num>0&&num<=3,"num error");
        if (num==1){
            return permit1;
        }else if(num==2){
            return permit2;
        }
        return permit3;

    }

    //获取授权情况
    function getPermitNum()external  view  returns (uint8){
        if (permit1&&permit2&&permit3){
            return 3;
        }else if (permit1&&permit2||permit2&&permit3||permit1&&permit3){
            return 2;
        }else if (permit1||permit2||permit3){
            return 1;
        }else  {
            return 0;
        }
    }

    //授权
    function empower() external payable {
        require(msg.sender==admin1||msg.sender==admin2||msg.sender==admin3,"address not compliant");
        if (msg.sender==admin1){
            permit1 = true;
        }else if(msg.sender==admin2){
            permit2 =true;
        }else{
            permit3 = true;
        }
    } 
    //取消授权
    function cancleEmpower() external payable {
        require(msg.sender==admin1||msg.sender==admin2||msg.sender==admin3,"address not compliant");
        if (msg.sender==admin1){
            permit1 = false;
        }else if(msg.sender==admin2){
            permit2 =false;
        }else{
            permit3 = false;
        }
    } 

    //余额查询 (eth,weth)
    function getBalance() external view returns(uint ,uint ){
        return (address(this).balance,IWETH9(WETH).balanceOf(address(this)));
    }

    

    //充值WETH
    function deposit(uint amount)external payable {
        require(msg.sender==admin1||msg.sender==admin2||msg.sender==admin3,"address not compliant");
        require(address(this).balance>=amount,"insufficient eth");
        WETH.call{value:amount,gas:23000}("");
    }

    //提现
    function withDraw(address to,uint256 amount) external payable {
        require(msg.sender==admin1||msg.sender==admin2||msg.sender==admin3,"address not compliant");
        require(permit1&&permit2||permit1&&permit3||permit2&&permit3,"insufficient authorization");
        require(IWETH9(WETH).balanceOf(address(this))+address(this).balance>=amount,"insufficient assets");
        if (address(this).balance<amount){
            IWETH9(WETH).withdraw(amount-address(this).balance);
        }
        payable(to).transfer(amount);
    }


    function v2ToV3(
        uint v2AmountIn,
        uint v2AmountOutMin,
        address[] calldata path,
        uint24 fee,
        uint256 v3AmountOutMinimum,
        uint256 blockChainFee,
        uint deadline
        ) external payable checkDeadline(deadline) {
            require(msg.sender==admin1||msg.sender==admin2||msg.sender==admin3,"address not compliant");
            require(IWETH9(WETH).balanceOf(address(this))>=v2AmountIn,"insufficient weth");
            require(path.length==2&&path[0]==WETH,"path length error or path0 is not weth");
            IWETH9(WETH).approve(v2Router,v2AmountIn);
            IUniswapV2Router02(v2Router).swapExactTokensForTokensSupportingFeeOnTransferTokens(v2AmountIn,v2AmountOutMin,path,address(this),deadline);
            uint256 v3AmountIn = IERC20(path[1]).balanceOf(address(this));
            IERC20(path[1]).approve(v3Router,v3AmountIn);
            uint256 v3AmountOut=IV3SwapRouter(v3Router).exactInputSingle(IV3SwapRouter.ExactInputSingleParams(path[1],path[0],fee,address(this),v3AmountIn,v3AmountOutMinimum,0));
            require(v3AmountOut>=v2AmountIn+blockChainFee,"no profit");
            profit = uint256(v3AmountOut-v2AmountIn-blockChainFee);
        }


    function v3ToV2(
        uint v3AmountIn,
        uint v3AmountOutMinimum,
        address[] calldata path,  //path对于v3是反的   1是WETH,0是ERC20
        uint24 fee,
        uint256 v2AmountOutMin,
        uint256 blockChainFee,
        uint deadline
        ) external payable checkDeadline(deadline) {
            require(msg.sender==admin1||msg.sender==admin2||msg.sender==admin3,"address not compliant");
            require(IWETH9(WETH).balanceOf(address(this))>=v3AmountIn,"insufficient weth");
            require(path.length==2&&path[1]==WETH,"path length error or path0 is not weth");
            IWETH9(WETH).approve(v3Router,v3AmountIn);
            uint oldWETHBalance = IWETH9(WETH).balanceOf(address(this));
            uint256 v3AmountOut =IV3SwapRouter(v3Router).exactInputSingle(IV3SwapRouter.ExactInputSingleParams(path[1],path[0],fee,address(this),v3AmountIn,v3AmountOutMinimum,0));
            IERC20(path[0]).approve(v2Router,v3AmountOut);
            IUniswapV2Router02(v2Router).swapExactTokensForTokensSupportingFeeOnTransferTokens(v3AmountOut,v2AmountOutMin,path,address(this),deadline);
            require(IWETH9(WETH).balanceOf(address(this))>=blockChainFee+oldWETHBalance,"no profit");
            profit = uint256(IWETH9(WETH).balanceOf(address(this))-blockChainFee-oldWETHBalance);
        }


    receive() external payable { }
    fallback() external payable { }
}