// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IERC7765.sol";

contract ImKeyNFTContract is
    Initializable,
    ERC721Upgradeable,
    IERC7765,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    string private _defaultURI;

    uint256 private _nextTokenId;

    address public usdtToken;
    address public usdcToken;
    uint256 public mintPrice;

    uint256[] public privilegeIdsArr;
    mapping(uint256 privilegeId => bool) public privilegeIdStatus;

    mapping(uint256 => bool) public tokenPrivilegeUsed;
    mapping(uint256 tokenId => mapping(uint256 privilegeId => address to)) public tokenPrivilegeAddress;
    mapping(address to => mapping(uint256 privilegeId => uint256[] tokenIds)) public addressPrivilegedUsedToken;

    event UpdatePrivilegeIds(uint256 indexed privilegeId, bool indexed status);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address initialOwner,
        address _usdtToken,
        address _usdcToken,
        uint256 _mintPrice
    ) external initializer {
        __ERC721_init("imKey Pro RWA NFT", "IKPRN");
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        usdtToken = _usdtToken;
        usdcToken = _usdcToken;
        mintPrice = _mintPrice;
        privilegeIdsArr = [1];
        privilegeIdStatus[1] = true;
    }

    function withdrawUSD(address payTokenAddress) external onlyOwner {
        IERC20 erc20Token = IERC20(payTokenAddress);
        uint256 contractBalance = erc20Token.balanceOf(address(this));
        require(contractBalance > 0, "No USD to withdraw");
        erc20Token.transfer(owner(), contractBalance);
    }

    function mint(address payTokenAddress) external {
        address sender = _msgSender();
        require(
            payTokenAddress == usdtToken || payTokenAddress == usdcToken,
            "Only support USDT/USDC"
        );
        IERC20 erc20Token = IERC20(payTokenAddress);
        require(
            erc20Token.balanceOf(sender) >= mintPrice,
            "Insufficient USD balance"
        );
        require(
            erc20Token.allowance(sender, address(this)) >= mintPrice,
            "Allowance not set for USD"
        );

        bool success = erc20Token.transferFrom(
            sender,
            address(this),
            mintPrice
        );
        require(success, "USD transfer failed");
        _mint(sender, ++_nextTokenId);
    }

    function exercisePrivilege(
        address _to,
        uint256 _tokenId,
        uint256 _privilegeId,
        bytes calldata _data
    ) external override {
        _requireOwned(_tokenId);
        require(_msgSender() == _to, "Invalid address: _to must be sender");
        require(
            _to == _ownerOf(_tokenId),
            "Invalid address: _to must be owner of _tokenId"
        );
        require(privilegeIdsArrContains(_privilegeId), "Invalid _privilegeId");
        require(_data.length == 0, "_data must be null");
        require(privilegeIdStatus[_privilegeId], "_privilegeId status error");
        require(
            !tokenPrivilegeUsed[_tokenId],
            "The tokenID has been exercised"
        );

        tokenPrivilegeUsed[_tokenId] = true;
        tokenPrivilegeAddress[_tokenId][_privilegeId] = _to;
        addressPrivilegedUsedToken[_to][_privilegeId].push(_tokenId);

        emit PrivilegeExercised(_to, _to, _tokenId, _privilegeId);
    }

    /// @notice This function is to check whether a specific privilege of a token can be exercised.
    /// @dev Throws if `_privilegeId` is not a valid privilegeId.
    /// @param _to  the address to benefit from the privilege.
    /// @param _tokenId  the NFT tokenID.
    /// @param _privilegeId  the ID of the privileges.
    function isExercisable(
        address _to,
        uint256 _tokenId,
        uint256 _privilegeId
    ) external view override returns (bool _exercisable) {
        _requireOwned(_tokenId);
        require(
            _to == _ownerOf(_tokenId),
            "Invalid address: _to must be owner of _tokenId"
        );

        return privilegeIdStatus[_privilegeId] && !tokenPrivilegeUsed[_tokenId];
    }

    /// @notice This function is to check whether a specific privilege of a token has been exercised.
    /// @dev Throws if `_privilegeId` is not a valid privilegeId.
    /// @param _to  the address to benefit from the privilege.
    /// @param _tokenId  the NFT tokenID.
    /// @param _privilegeId  the ID of the privileges.
    function isExercised(
        address _to,
        uint256 _tokenId,
        uint256 _privilegeId
    ) external view override returns (bool _exercised) {
        _requireOwned(_tokenId);
        require(
            _to == _ownerOf(_tokenId),
            "Invalid address: _to must be owner of _tokenId"
        );
        return privilegeIdStatus[_privilegeId] && tokenPrivilegeUsed[_tokenId];
    }

    /// @notice This function is to list all privilegeIds of a token.
    /// @param _tokenId  the NFT tokenID.
    function getPrivilegeIds(
        uint256 _tokenId
    ) external view returns (uint256[] memory privilegeIds) {
        _requireOwned(_tokenId);
        return privilegeIdsArr;
    }

    function setDefaultURI(string calldata uri) external onlyOwner {
        _defaultURI = uri;
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        _requireOwned(tokenId);
        return _defaultURI;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) public override {
        _requireOwned(_tokenId);
        require(_msgSender() == _from, "Invalid address: _from must be sender");
        require(
            _from == ownerOf(_tokenId),
            "Invalid address: _from must be owner of _tokenId"
        );
        super.transferFrom(_from, _to, _tokenId);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function privilegeIdsArrContains(
        uint256 privilegeId
    ) internal view returns (bool) {
        for (uint256 i = 0; i < privilegeIdsArr.length; i++) {
            if (privilegeIdsArr[i] == privilegeId) {
                return true;
            }
        }
        return false;
    }
}
