// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IERC7765.sol";
import "../interfaces/IERC7765Metadata.sol";
import "../interfaces/IMetadataRenderer.sol";

contract ImKeyNFTContract is
    Initializable,
    ERC721Upgradeable,
    IERC7765,
    IERC7765Metadata,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;
    address public metadataRenderer;
    address public privilegeMetadataRenderer;

    uint256 private _nextTokenId;

    address public constant PAYMENT_RECEIPIENT_ADDRESS =
        0xC0f068774D46ba26013677b179934Efd7bdefA3F;
    address public constant POSTAGE_RECEIPIENT_ADDRESS =
        0xC0f068774D46ba26013677b179934Efd7bdefA3F;
    address public constant USDT_ADDRESS =
        0xED85184DC4BECf731358B2C63DE971856623e056;
    address public constant USDC_ADDRESS =
        0xBAfC2b82E53555ae74E1972f3F25D8a0Fc4C3682;

    uint256 public constant MINT_PRICE = 60 * 10 ** 6;

    uint256 public constant PRIVILEGE_ID = 1;

    mapping(uint256 tokenId => address to) public tokenPrivilegeAddress;
    mapping(address to => uint256[] tokenIds) public addressPrivilegedUsedToken;
    mapping(uint256 tokenId => uint256 postage) public postageMessage;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) external initializer {
        __ERC721_init("imKey Pro RWA NFT", "IKPRN");
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }

    modifier checkPrivilegeId(uint256 _privilegeId) {
        require(_privilegeId == PRIVILEGE_ID, "Invalid _privilegeId");
        _;
    }

    function mint(address payTokenAddress, uint256 amounts) external {
        address sender = _msgSender();
        require(
            payTokenAddress == USDT_ADDRESS || payTokenAddress == USDC_ADDRESS,
            "Only support USDT/USDC"
        );
        require(
            amounts > 0 && amounts <= 10000,
            "One times max limit mint 10000"
        );
        IERC20 erc20Token = IERC20(payTokenAddress);
        uint256 payPrice = MINT_PRICE * amounts;
        require(
            erc20Token.balanceOf(sender) >= payPrice,
            "Insufficient USD balance"
        );
        require(
            erc20Token.allowance(sender, address(this)) >= payPrice,
            "Allowance not set for USD"
        );

        erc20Token.safeTransferFrom(
            sender,
            PAYMENT_RECEIPIENT_ADDRESS,
            payPrice
        );

        for (uint256 i = 0; i < amounts; ) {
            _mint(sender, ++_nextTokenId);
            unchecked {
                ++i;
            }
        }
    }

    function exercisePrivilege(
        address _to,
        uint256 _tokenId,
        uint256 _privilegeId,
        bytes calldata _data
    ) external override checkPrivilegeId(_privilegeId) {
        _requireOwned(_tokenId);

        address tokenOwner = _ownerOf(_tokenId);
        address sender = _msgSender();
        (address payTokenAddress, uint256 postage) = abi.decode(
            _data,
            (address, uint256)
        );
        IERC20 erc20Token = IERC20(payTokenAddress);

        require(
            sender == tokenOwner,
            "Invalid address: sender must be owner of tokenID"
        );
        require(
            _to == tokenOwner,
            "Invalid address: _to must be owner of _tokenId"
        );

        require(
            tokenPrivilegeAddress[_tokenId] == address(0),
            "The tokenID has been exercised"
        );

        require(
            payTokenAddress == USDT_ADDRESS || payTokenAddress == USDC_ADDRESS,
            "Only support USDT/USDC"
        );

        if (postage > 0) {
            erc20Token.safeTransferFrom(
                sender,
                POSTAGE_RECEIPIENT_ADDRESS,
                postage
            );
            postageMessage[_tokenId] = postage;
        }

        tokenPrivilegeAddress[_tokenId] = _to;
        addressPrivilegedUsedToken[_to].push(_tokenId);

        emit PrivilegeExercised(sender, _to, _tokenId, _privilegeId);
    }

    function isExercisable(
        address _to,
        uint256 _tokenId,
        uint256 _privilegeId
    )
        external
        view
        override
        checkPrivilegeId(_privilegeId)
        returns (bool _exercisable)
    {
        _requireOwned(_tokenId);

        return
            _to == _ownerOf(_tokenId) &&
            tokenPrivilegeAddress[_tokenId] == address(0);
    }

    function isExercised(
        address _to,
        uint256 _tokenId,
        uint256 _privilegeId
    )
        external
        view
        override
        checkPrivilegeId(_privilegeId)
        returns (bool _exercised)
    {
        _requireOwned(_tokenId);

        return
            tokenPrivilegeAddress[_tokenId] != address(0) &&
            tokenPrivilegeAddress[_tokenId] == _to;
    }

    function getPrivilegeIds(
        uint256 _tokenId
    ) external view returns (uint256[] memory privilegeIds) {
        _requireOwned(_tokenId);
        privilegeIds = new uint256[](1);
        privilegeIds[0] = PRIVILEGE_ID;
    }

    function setMetadataRenderer(address _metadataRenderer) external onlyOwner {
        require(_metadataRenderer != address(0), "Invalid address");
        metadataRenderer = _metadataRenderer;
    }
    function tokenURI(
        uint256 _tokenId
    ) public view override returns (string memory) {
        _requireOwned(_tokenId);
        return IMetadataRenderer(metadataRenderer).tokenURI(_tokenId);
    }

    function setPrivilegeMetadataRenderer(
        address _privilegeMetadataRenderer
    ) external onlyOwner {
        require(_privilegeMetadataRenderer != address(0), "Invalid address");
        privilegeMetadataRenderer = _privilegeMetadataRenderer;
    }

    function privilegeURI(
        uint256 _privilegeId
    )
        external
        view
        override
        checkPrivilegeId(_privilegeId)
        returns (string memory)
    {
        return
            IERC7765Metadata(privilegeMetadataRenderer).privilegeURI(
                _privilegeId
            );
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
