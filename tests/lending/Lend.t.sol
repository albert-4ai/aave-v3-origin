// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/* solhint-disable */

import "forge-std/Test.sol";

// 将路径更新为 aave-v3-origin
import {IPool} from "../../src/contracts/interfaces/IPool.sol";

// 将路径更新为 aave-v3-origin
import {IERC20} from "../../src/contracts/dependencies/openzeppelin/contracts/IERC20.sol";

contract AaveFlowTest is Test {
    // --- 核心地址常量 (以太坊主网) --- // 
    // Aave V3 Pool Proxy 地址 
    address constant POOL_ADDRESS = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    // WETH 地址 (作为抵押品) 
    address constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; 
    // USDC 地址 (作为借出资产) 
    address constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; 

    IPool pool; 
    IERC20 weth; 
    IERC20 usdc; 
    
    // 定义测试用户 
    address user = address(1); 

    function setUp() public { 
        // ============================================================
        // 1. Fork 主网设置
        // ============================================================
        // --rpc-url 的作用：
        //   - 仅用于与 RPC 节点通信（查询数据、发送交易等）
        //   - 不会 fork 链的状态到本地测试环境
        //   - 测试环境仍然是空的，合约地址不存在
        // 
        // --fork-url 的作用：
        //   - Fork 指定链的状态到本地测试环境
        //   - 创建一个本地 EVM 实例，复制指定区块的所有状态
        //   - 包括：合约代码、存储、账户余额等
        //   - 允许你在本地测试环境中与 fork 的链交互
        // 
        // 对于测试 Aave V3：
        //   - 我们需要访问主网上已部署的合约（0x87870BCa3f3fD6335c3FDCC7da3A1eAA6f80557f）
        //   - 必须 fork 主网状态，否则合约地址不存在
        // 
        // 运行方式（推荐）: 使用 --fork-url 参数（fork 到最新区块）
        //   forge test --match-path tests/lending/Lend.t.sol --fork-url YOUR_RPC_URL
    
        if (block.chainid != 1) {
            // 如果不在主网，尝试手动 fork 主网
            string memory forkUrl;
            
            // 优先尝试从环境变量或 foundry.toml 读取
            try vm.rpcUrl("mainnet") returns (string memory url) {
                forkUrl = url;
            } catch {
                revert(
                    "Not on mainnet and RPC_MAINNET not configured.\n"
                    "Please use one of the following:\n"
                    "  1. forge test --fork-url YOUR_RPC_URL\n"
                    "  2. export RPC_MAINNET=YOUR_RPC_URL && forge test --fork-url $RPC_MAINNET\n"
                    "  3. Configure RPC_MAINNET in foundry.toml and use --fork-url $RPC_MAINNET"
                );
            }
            
            // 尝试 fork 到主网最新区块
            try vm.createSelectFork(forkUrl) {
                // Fork 到最新区块成功
            } catch {
                revert(
                    "Failed to fork mainnet. Possible reasons:\n"
                    "1. RPC URL is invalid or unreachable\n"
                    "2. RPC URL is incomplete (missing API key?)\n"
                    "3. RPC node doesn't support forking\n"
                    "4. Network connectivity issues\n\n"
                    "Example correct command:\n"
                    "  forge test --fork-url https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY"
                );
            }
        }
        
        // ============================================================
        // 2. 验证 Pool 合约是否存在
        // ============================================================
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(POOL_ADDRESS)
        }
        
        if (codeSize == 0) {
            // 合约不存在，提供详细的错误信息和解决方案
            string memory currentBlock = vm.toString(block.number);
            string memory currentChainId = vm.toString(block.chainid);
            
            revert(
                string.concat(
                    "Current Chain ID: ", currentChainId, " (expected: 1)\n",
                    "Current Block: ", currentBlock, "\n\n",
                    "Possible reasons:\n",
                    "1. Not forking mainnet - use --fork-url YOUR_RPC_URL\n",
                    "2. Forked block is too old (Aave V3 deployed in Jan 2023)\n",
                    "3. RPC URL is incomplete or invalid (check API key)\n",
                    "4. RPC node has pruned the state for this block\n\n",
                    "Solutions:\n",
                    "1. Use: forge test --fork-url https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY\n",
                    "2. Add block number: --fork-block-number 19000000\n",
                    "3. Verify RPC URL includes your API key\n",
                    "4. Try a different RPC provider (Alchemy, Infura)"
                )
            );
        } 

        // 2. 初始化接口 
        pool = IPool(POOL_ADDRESS); 
        weth = IERC20(WETH_ADDRESS); 
        usdc = IERC20(USDC_ADDRESS); 
        
        // 3. 准备资金：使用 'deal' 作弊码给 user 发 10 个 WETH 
        deal(WETH_ADDRESS, user, 10 ether); 
    } 

    function test_SupplyAndBorrow() public { 
        // 切换到用户身份执行后续操作 
        vm.startPrank(user); 

        // --- 步骤 1: 存款 (Supply) --- 
        console.log("1. User WETH balance before:", weth.balanceOf(user)); 
        // 批准 Aave Pool 扣款 
        weth.approve(POOL_ADDRESS, 10 ether); 
        // 执行 Supply: 资产地址, 数量, 代表谁存入, referralCode(0) 
        pool.supply(WETH_ADDRESS, 10 ether, user, 0); 
        console.log("-> Supplied 10 WETH to Aave V3"); 

        // --- 步骤 2: 验证抵押状态 --- 
        (,,,,, uint256 healthFactor) = pool.getUserAccountData(user); 
        console.log("-> Health Factor after supply:", healthFactor); 
        // 健康因子应该非常大，因为还没借钱 

        // --- 步骤 3: 借款 (Borrow) --- 
        // 记录借款前的 USDC 余额（fork 的主网上可能已有余额）
        uint256 usdcBalanceBefore = usdc.balanceOf(user);
        console.log("User USDC Balance before borrow:", usdcBalanceBefore);
        
        // 借出 1000 USDC (USDC 精度是 6) 
        uint256 borrowAmount = 1000 * 1e6; 
        // 执行 Borrow: 资产地址, 数量, 利率模式(2=变动利率), referralCode(0), 接收地址 
        pool.borrow(USDC_ADDRESS, borrowAmount, 2, 0, user); 
        console.log("-> Borrowed 1000 USDC"); 

        // --- 步骤 4: 验证结果 --- 
        uint256 usdcBalanceAfter = usdc.balanceOf(user); 
        uint256 usdcReceived = usdcBalanceAfter - usdcBalanceBefore;
        console.log("User USDC Balance after borrow:", usdcBalanceAfter);
        console.log("USDC received from borrow:", usdcReceived);
        
        // 验证实际收到的 USDC 等于借款金额
        assertEq(usdcReceived, borrowAmount, "Borrow failed or amount mismatch"); 
        
        // 再次查看健康因子 (借钱后应该下降) 
        (,,,,, uint256 newHealthFactor) = pool.getUserAccountData(user); 
        console.log("-> Health Factor after borrow:", newHealthFactor); 
        
        vm.stopPrank(); 
    }
}
