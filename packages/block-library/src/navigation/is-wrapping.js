/**
 * Determines if the children of a wrapper element are wrapping.
 *
 * @param {Element} wrapper  The element to determine if its children are wrapping
 * @param {Array}   children The children of the wrapper element
 *
 * @return {boolean} Whether the children of the wrapper element are wrapping.
 */
function areItemsWrapping(
	wrapper,
	children = wrapper.querySelectorAll( 'li' )
) {
	const wrapperDimensions = wrapper.getBoundingClientRect();
	//we store an array with the width of each item
	const itemsWidths = getItemWidths( children );
	let totalWidth = 0;
	let isWrapping = false;

	//the nav block may have row-gap applied, which is not calculated in getItemWidths
	const computedStyle = window.getComputedStyle( wrapper );
	const rowGap = parseFloat( computedStyle.rowGap ) || 0;

	for ( let i = 0, len = itemsWidths.length; i < len; i++ ) {
		totalWidth += itemsWidths[ i ];
		if ( rowGap > 0 && i > 0 ) {
			totalWidth += rowGap;
		}
		if ( parseInt( totalWidth ) > parseInt( wrapperDimensions.width ) ) {
			isWrapping = true;
		}
	}
	return isWrapping;
}

/**
 * Determines if the navigation element itself is wrapping.
 *
 * @param {Element} navElement Wrapper element of the navigation block.
 * @return {boolean} Whether the nav element itself is wrapping.
 */
function isNavElementWrapping( navElement ) {
	let isWrapping = false;
	//how can we check if the nav element is wrapped inside its parent if we don't know anything about it (the parent)?
	if ( navElement !== null ) {
		const childrenWrapper = navElement.querySelector(
			'ul.wp-block-navigation'
		);
		isWrapping =
			childrenWrapper &&
			childrenWrapper.children &&
			areItemsWrapping(
				navElement,
				Array.from(
					navElement.querySelector( 'ul.wp-block-navigation' )
						.children
				)
			);
	}
	return isWrapping;
}

/**
 * Returns an array with the width of each item.
 *
 * @param {Array} items The items to get the width of.
 * @return {Array} An array with the width of each item.
 */
function getItemWidths( items ) {
	const itemsWidths = [];

	items.forEach( function ( item ) {
		const style = item.currentStyle || window.getComputedStyle( item );
		const itemDimensions = item.getBoundingClientRect();
		const width = parseFloat( itemDimensions.width );
		const marginLeft = parseFloat( style.marginLeft );
		const marginRight = parseFloat( style.marginRight );
		const totalWidth = width + marginLeft + marginRight;

		itemsWidths.push( totalWidth );
	} );
	return itemsWidths;
}

/**
 * Determines if the navigation block is wrapping.
 *
 * @param {Element} navElement Wrapper element of the navigation block.
 * @return {boolean} Whether the navigation block is wrapping.
 */
function navigationIsWrapping( navElement ) {
	if ( ! navElement ) {
		return false;
	}

	return (
		areItemsWrapping( navElement ) === true ||
		isNavElementWrapping( navElement ) === true
	);
}

export default navigationIsWrapping;
