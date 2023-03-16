import asyncio
import json

from sys import argv
from starknet_py.contract import Contract
from starknet_py.net import AccountClient, KeyPair
from starknet_py.net.gateway_client import GatewayClient
from starknet_py.net.networks import MAINNET

# Local network
from starknet_py.net.models import StarknetChainId
from starknet_py.transactions.declare import make_declare_tx
from starkware.starknet.compiler.compile import get_selector_from_name

from utils import str_to_felt, decimal_to_hex, to_uint

ADDRESS = "0x123"
PUBLIC_KEY = 0x321
PRIVATE_KEY = 987654321

OWNER = 0x123

COLLECTION_NAME = str_to_felt('Mystis OG Pass')
COLLECTION_SYMBOL = str_to_felt('MOGP')
TOKEN_URI = [
    str_to_felt("https://gateway.pinata.cloud/ip"),
    str_to_felt("fs/QmNNhGMNGppvMhZ438m51qSJ5g6Q"),
    str_to_felt("7kmXiFcbtnda6t3khh/"),
]
TOKEN_URI_LEN = len(TOKEN_URI)
TOKEN_URI_SUFFIX = str_to_felt('.json')
MAX_SUPPLY = to_uint(555)
FEE_BASIS_POINTS = 750

CONTRACT_URI = [
    str_to_felt("https://gateway.pinata.cloud/ip"),
    str_to_felt("fs/QmUoW7druoHnJeaW1N6NuTWqZwbY"),
    str_to_felt("8Hsb7HFu2qDYv4PwPN"),
]
CONTRACT_URI_LEN = len(CONTRACT_URI)

async def setup_accounts():
    network = GatewayClient(MAINNET)
    account = AccountClient(
        client=network, 
        address=ADDRESS,
        key_pair=KeyPair(private_key=PRIVATE_KEY, public_key=PUBLIC_KEY),
        chain=StarknetChainId.MAINNET,
        supported_tx_version=1,
    )
    print("✅ Account instance on MAINNET has been created")
    return account

async def declare_contract(account, contract_src):
    declare_tx = make_declare_tx(compilation_source=[contract_src])
    return await account.declare(declare_tx)

async def setup_mystis_nft_contract(account):
    print("⏳ Declaring Mystis OG Pass contract...")
    declare_result = await declare_contract(account, "contracts/MystisOGPass.cairo")
    print("✅ Mystis OG Pass contract has been declared")
    selector = get_selector_from_name("initializer")
    mystis_nft_constructor_args = [
        COLLECTION_NAME,
        COLLECTION_SYMBOL,
        OWNER,
        TOKEN_URI_LEN,
        *TOKEN_URI,
        TOKEN_URI_SUFFIX,
        *MAX_SUPPLY,
        #account.address
        FEE_BASIS_POINTS,
    ]
    print("⏳ Declaring Proxy Contract...")
    proxy_declare_tx = await account.sign_declare_transaction(
        compilation_source=["contracts/MystisProxy.cairo"], 
        max_fee=int(1e16)
    )
    resp = await account.declare(transaction=proxy_declare_tx)
    await account.wait_for_tx(resp.transaction_hash)
    print("✅ Proxy Contract has been declared")

    with open("artifacts/abis/MystisProxy.json", "r") as proxy_abi_file:
        proxy_abi = json.load(proxy_abi_file)

    deployment_result = await Contract.deploy_contract(
        account=account,
        class_hash=resp.class_hash,
        abi=proxy_abi,
        constructor_args=[
            declare_result.class_hash,
            selector,
            mystis_nft_constructor_args,
        ],
        max_fee=int(1e16),
    )
    print(f'✨ Contract deployed at {decimal_to_hex(deployment_result.deployed_contract.address)}')
    await deployment_result.wait_for_acceptance()
    proxy = deployment_result.deployed_contract
    with open("artifacts/abis/MystisOGPass.json", "r") as abi_file:
        implementation_abi = json.load(abi_file)

    proxy = Contract(
        address=proxy.address,
        abi=implementation_abi,
        client=account
    )
    return proxy

async def main():
    account = await setup_accounts()
    mystis_nft_proxy_contract = await setup_mystis_nft_contract(account)

    print("⏳ Calling `getAdmin` function...")
    (mystis_nft_proxy_admin,) = await mystis_nft_proxy_contract.functions["getAdmin"].call()
    assert account.address == mystis_nft_proxy_admin
    print("The proxy admin was set to our account:", hex(mystis_nft_proxy_admin))

    print("⏳ Calling `setContractURI` function...")
    invoke_tx =  await mystis_nft_proxy_contract.functions["setContractURI"].invoke([*CONTRACT_URI], max_fee=int(1e16))
    await invoke_tx.wait_for_acceptance()
    print("The uri of the contract has been defined correctly.")

if __name__ == "__main__":
    asyncio.run(main())