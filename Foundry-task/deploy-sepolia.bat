REM Read first
source .env
REM Then execute deployment command
forge script script/Deploy.s.sol:DeployScript ^
--rpc-url %SEPOLIA_RPC_URL% 
--private-key %PRIVATE_KEY% 
--broadcast 
--verify 
-vvvv 

REM Successfully deployed version
forge script script/Deploy.s.sol --rpc-url %SEPOLIA_RPC_URL%.--private-key %PRIVATE_KEY%--broadcast --verify -vvvv


@REM Hardcoded environment version
forge script script/Deploy.s.sol --rpc-url "https://eth-sepolia.g.alchemy.com/v2/" --private-key "0x" --broadcast --verify -vvvv



REM mac version (TOML configuration)
forge script script/DeployRemainingContracts.s.sol:DeployRemainingContracts \
    --chain-id 11155111 \
    --rpc-url sepolia  \
    --etherscan-api-key sepolia \
    --broadcast \
    --slow \
    --verify \
    -vvvv

REM win bash version (TOML configuration)
dotenv -e .env -- forge script script/UpgradeTPNFTMarket.sol \
    --chain-id 11155111 \
    --rpc-url sepolia  \
    --etherscan-api-key sepolia \
    --broadcast \
    --slow \
    --verify \
    -vvvv

