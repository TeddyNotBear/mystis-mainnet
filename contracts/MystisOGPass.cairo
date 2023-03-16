// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address 
from starkware.cairo.common.uint256 import Uint256, uint256_add, uint256_lt
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE

from openzeppelin.security.pausable.library import Pausable
from openzeppelin.access.ownable.library import Ownable
from openzeppelin.security.reentrancyguard.library import ReentrancyGuard
from openzeppelin.upgrades.library import Proxy
from openzeppelin.token.erc721.library import ERC721
from openzeppelin.token.erc721.enumerable.library import ERC721Enumerable
from openzeppelin.introspection.erc165.library import ERC165

from contracts.token.erc2981.unidirectional_mutable import ERC2981_UniDirectional_Mutable
from contracts.token.ERC721.ERC721_Metadata_base import (
    ERC721_Metadata_initializer,
    ERC721_Metadata_tokenURI,
    ERC721_Metadata_setBaseTokenURI,
)

@storage_var
func counter_id() -> (token_id: Uint256) {
}

@storage_var
func max_supply() -> (supply: Uint256) {
}

@storage_var
func contract_uri(index: felt) -> (contractURI: felt) {
}

@storage_var
func contract_uri_len() -> (contractURI_len: felt) {
}

@external
func initializer{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(
    name: felt,
    symbol: felt,
    owner: felt, 
    base_token_uri_len: felt,
    base_token_uri: felt*,
    token_uri_suffix: felt,
    supply: Uint256,
    fee_basis_points: felt
) {
    ERC721.initializer(name, symbol);
    ERC721_Metadata_initializer();
    ERC721Enumerable.initializer();
    Ownable.initializer(owner);
    Proxy.initializer(owner);
    ERC2981_UniDirectional_Mutable.initializer(owner, fee_basis_points);
    ERC721_Metadata_setBaseTokenURI(base_token_uri_len, base_token_uri, token_uri_suffix);
    max_supply.write(supply);
    counter_id.write(Uint256(1, 0));
    return ();
}

//
// Getters
//

@view
func contractURI{
    syscall_ptr: felt*, 
    pedersen_ptr: HashBuiltin*, 
    range_check_ptr
}() -> (contractURI_len: felt, contractURI: felt*) { 
    alloc_locals;
    let (local base_contract_uri) = alloc();
    let (local contractURI_len) = contract_uri_len.read();
    _contractURI(contractURI_len, base_contract_uri);
    return (contractURI_len=contractURI_len, contractURI=base_contract_uri);
}

@view
func royaltyInfo{
    syscall_ptr: felt*, 
    pedersen_ptr: HashBuiltin*, 
    range_check_ptr
}(tokenId: Uint256, salePrice: Uint256) -> (
    receiver: felt, royaltyAmount: Uint256
) {
    let exists = ERC721._exists(tokenId);
    with_attr error_message("ERC721: token id does not exist") {
        assert exists = TRUE;
    }
    let (receiver: felt, royaltyAmount: Uint256) = ERC2981_UniDirectional_Mutable.royalty_info(
        tokenId, salePrice
    );
    return (receiver, royaltyAmount);
}

@view
func tokenURI{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(token_id: Uint256) -> (token_uri_len: felt, token_uri: felt*) {
    let (token_uri_len, token_uri) = ERC721_Metadata_tokenURI(token_id);
    return (token_uri_len, token_uri);
}

@view
func maxSupply{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}() -> (supply: Uint256) {
    let (supply: Uint256) = max_supply.read();
    return (supply,);
}

@view
func totalMintedOGPass{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}() -> (supply: Uint256) {
    let (supply) = ERC721Enumerable.total_supply();
    return (supply,);
}

@view
func getImplementationHash{
    syscall_ptr: felt*, 
    pedersen_ptr: HashBuiltin*, 
    range_check_ptr
}() -> (implementation: felt) {
    return Proxy.get_implementation_hash();
}

@view
func getAdmin{
    syscall_ptr: felt*, 
    pedersen_ptr: HashBuiltin*, 
    range_check_ptr
}() -> (admin: felt) {
    return Proxy.get_admin();
}

@view
func name{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}() -> (name: felt) {
    return ERC721.name();
}

@view
func symbol{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}() -> (symbol: felt) {
    return ERC721.symbol();
}

@view
func balanceOf{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(owner: felt) -> (balance: Uint256) {
    return ERC721.balance_of(owner);
}

@view
func ownerOf{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(token_id: Uint256) -> (owner: felt) {
    return ERC721.owner_of(token_id);
}

@view
func getApproved{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(token_id: Uint256) -> (approved: felt) {
    return ERC721.get_approved(token_id);
}

@view
func isApprovedForAll{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(owner: felt, operator: felt) -> (isApproved: felt) {
    let (isApproved) = ERC721.is_approved_for_all(owner, operator);
    return (isApproved=isApproved);
}

@view
func paused{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}() -> (paused: felt) {
    return Pausable.is_paused();
}

@view
func owner{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}() -> (owner: felt) {
    return Ownable.owner();
}

@view
func supportsInterface{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(interfaceId: felt) -> (success: felt) {
    return ERC165.supports_interface(interfaceId);
}

//
// Externals
//

@external
func mint{
    syscall_ptr: felt*, 
    pedersen_ptr: HashBuiltin*, 
    range_check_ptr
}() {
    alloc_locals;
    ReentrancyGuard.start();
    Pausable.assert_not_paused();

    let (caller_address) = get_caller_address();
    let (total_minted_og_pass: Uint256) = totalMintedOGPass();
    let (max_supply: Uint256) = maxSupply();

    with_attr error_message("No Mystis OG Pass left.") {
        let (is_lt) = uint256_lt(total_minted_og_pass, max_supply);
        assert is_lt = 1;
    }

    let (user_balance: Uint256) = balanceOf(caller_address);
    with_attr error_message("You have already minted your OG Pass.") {
        let (is_lt) = uint256_lt(user_balance, Uint256(1, 0));
        assert is_lt = 1;
    }
    let (token_id: Uint256) = counter_id.read();
    ERC721Enumerable._mint(caller_address, token_id);
    let (res, _) = uint256_add(token_id, Uint256(1, 0));
    counter_id.write(res);

    ReentrancyGuard.end();
    return ();
}

@external
func setContractURI{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(contractURI_len: felt, contractURI: felt*) {
    Ownable.assert_only_owner();
    ReentrancyGuard.start();
    _setContractURI(contractURI_len, contractURI);
    contract_uri_len.write(contractURI_len);
    ReentrancyGuard.end();
    return ();
}

@external
func setMaxSupply{
    syscall_ptr: felt*, 
    pedersen_ptr: HashBuiltin*, 
    range_check_ptr
}(supply: Uint256) {
    Ownable.assert_only_owner();
    ReentrancyGuard.start();
    max_supply.write(supply);
    ReentrancyGuard.end();
    return ();
}

@external
func setTokenURI{
    syscall_ptr: felt*, 
    pedersen_ptr: HashBuiltin*, 
    range_check_ptr
}(base_token_uri_len: felt, base_token_uri: felt*, token_uri_suffix: felt) {
    Ownable.assert_only_owner();
    ERC721_Metadata_setBaseTokenURI(base_token_uri_len, base_token_uri, token_uri_suffix);
    return ();
}

@external
func approve{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(to: felt, tokenId: Uint256) {
    ReentrancyGuard.start();
    Pausable.assert_not_paused();
    ERC721.approve(to, tokenId);
    ReentrancyGuard.end();
    return ();
}

@external
func setApprovalForAll{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(operator: felt, approved: felt) {
    ReentrancyGuard.start();
    Pausable.assert_not_paused();
    ERC721.set_approval_for_all(operator, approved);
    ReentrancyGuard.end();
    return ();
}

@external
func transferFrom{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(from_: felt, to: felt, tokenId: Uint256) {
    ReentrancyGuard.start();
    Pausable.assert_not_paused();
    ERC721Enumerable.transfer_from(from_, to, tokenId);
    ReentrancyGuard.end();
    return ();
}

@external
func safeTransferFrom{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(from_: felt, to: felt, tokenId: Uint256, data_len: felt, data: felt*) {
    Pausable.assert_not_paused();
    ReentrancyGuard.start();
    ERC721Enumerable.safe_transfer_from(from_, to, tokenId, data_len, data);
    ReentrancyGuard.end();
    return ();
}

@external
func pause{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}() {
    Ownable.assert_only_owner();
    Pausable._pause();
    return ();
}

@external
func unpause{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}() {
    Ownable.assert_only_owner();
    Pausable._unpause();
    return ();
}

@external
func upgrade{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(new_implementation: felt) -> () {
    Proxy.assert_only_admin();
    Proxy._set_implementation_hash(new_implementation);
    return ();
}

@external
func transferOwnership{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(newOwner: felt) {
    Ownable.transfer_ownership(newOwner);
    return ();
}

@external
func renounceOwnership{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}() {
    Ownable.renounce_ownership();
    return ();
}

func _setContractURI{
    syscall_ptr: felt*, 
    pedersen_ptr: HashBuiltin*, 
    range_check_ptr
}(contractURI_len: felt, contractURI: felt*) {
    if (contractURI_len == 0) {
        return ();
    }
    contract_uri.write(index=contractURI_len, value=[contractURI]);
    _setContractURI(contractURI_len=contractURI_len - 1, contractURI=contractURI + 1);
    return ();
}

func _contractURI{
    syscall_ptr: felt*, 
    pedersen_ptr: HashBuiltin*, 
    range_check_ptr
}(base_contract_uri_len: felt, base_contract_uri: felt*) {
    if (base_contract_uri_len == 0) {
        return ();
    }
    let (base) = contract_uri.read(base_contract_uri_len);
    assert [base_contract_uri] = base;
    _contractURI(base_contract_uri_len=base_contract_uri_len - 1, base_contract_uri=base_contract_uri + 1);
    return ();
}