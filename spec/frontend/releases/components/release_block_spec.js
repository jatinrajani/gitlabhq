import { mount } from '@vue/test-utils';
import ReleaseBlock from '~/releases/list/components/release_block.vue';
import timeagoMixin from '~/vue_shared/mixins/timeago';
import { first } from 'underscore';
import { release } from '../mock_data';
import Icon from '~/vue_shared/components/icon.vue';
import { scrollToElement } from '~/lib/utils/common_utils';

let mockLocationHash;
jest.mock('~/lib/utils/url_utility', () => ({
  __esModule: true,
  getLocationHash: jest.fn().mockImplementation(() => mockLocationHash),
}));

jest.mock('~/lib/utils/common_utils', () => ({
  __esModule: true,
  scrollToElement: jest.fn(),
}));

describe('Release block', () => {
  let wrapper;

  const factory = releaseProp => {
    wrapper = mount(ReleaseBlock, {
      propsData: {
        release: releaseProp,
      },
    });
  };

  const milestoneListLabel = () => wrapper.find('.js-milestone-list-label');

  afterEach(() => {
    wrapper.destroy();
  });

  describe('with default props', () => {
    beforeEach(() => {
      factory(release);
    });

    it("renders the block with an id equal to the release's tag name", () => {
      expect(wrapper.attributes().id).toBe('v0.3');
    });

    it('renders release name', () => {
      expect(wrapper.text()).toContain(release.name);
    });

    it('renders commit sha', () => {
      expect(wrapper.text()).toContain(release.commit.short_id);

      wrapper.setProps({ release: { ...release, commit_path: '/commit/example' } });
      expect(wrapper.find('a[href="/commit/example"]').exists()).toBe(true);
    });

    it('renders tag name', () => {
      expect(wrapper.text()).toContain(release.tag_name);

      wrapper.setProps({ release: { ...release, tag_path: '/tag/example' } });
      expect(wrapper.find('a[href="/tag/example"]').exists()).toBe(true);
    });

    it('renders release date', () => {
      expect(wrapper.text()).toContain(timeagoMixin.methods.timeFormated(release.released_at));
    });

    it('renders number of assets provided', () => {
      expect(wrapper.find('.js-assets-count').text()).toContain(release.assets.count);
    });

    it('renders dropdown with the sources', () => {
      expect(wrapper.findAll('.js-sources-dropdown li').length).toEqual(
        release.assets.sources.length,
      );

      expect(wrapper.find('.js-sources-dropdown li a').attributes().href).toEqual(
        first(release.assets.sources).url,
      );

      expect(wrapper.find('.js-sources-dropdown li a').text()).toContain(
        first(release.assets.sources).format,
      );
    });

    it('renders list with the links provided', () => {
      expect(wrapper.findAll('.js-assets-list li').length).toEqual(release.assets.links.length);

      expect(wrapper.find('.js-assets-list li a').attributes().href).toEqual(
        first(release.assets.links).url,
      );

      expect(wrapper.find('.js-assets-list li a').text()).toContain(
        first(release.assets.links).name,
      );
    });

    it('renders author avatar', () => {
      expect(wrapper.find('.user-avatar-link').exists()).toBe(true);
    });

    describe('external label', () => {
      it('renders external label when link is external', () => {
        expect(wrapper.find('.js-assets-list li a').text()).toContain('external source');
      });

      it('does not render external label when link is not external', () => {
        expect(wrapper.find('.js-assets-list li:nth-child(2) a').text()).not.toContain(
          'external source',
        );
      });
    });

    it('renders the milestone icon', () => {
      expect(
        milestoneListLabel()
          .find(Icon)
          .exists(),
      ).toBe(true);
    });

    it('renders the label as "Milestones" if more than one milestone is passed in', () => {
      expect(
        milestoneListLabel()
          .find('.js-label-text')
          .text(),
      ).toEqual('Milestones');
    });

    it('renders a link to the milestone with a tooltip', () => {
      const milestone = first(release.milestones);
      const milestoneLink = wrapper.find('.js-milestone-link');

      expect(milestoneLink.exists()).toBe(true);

      expect(milestoneLink.text()).toBe(milestone.title);

      expect(milestoneLink.attributes('href')).toBe(milestone.web_url);

      expect(milestoneLink.attributes('data-original-title')).toBe(milestone.description);
    });
  });

  it('does not render the milestone list if no milestones are associated to the release', () => {
    const releaseClone = JSON.parse(JSON.stringify(release));
    delete releaseClone.milestones;

    factory(releaseClone);

    expect(milestoneListLabel().exists()).toBe(false);
  });

  it('renders the label as "Milestone" if only a single milestone is passed in', () => {
    const releaseClone = JSON.parse(JSON.stringify(release));
    releaseClone.milestones = releaseClone.milestones.slice(0, 1);

    factory(releaseClone);

    expect(
      milestoneListLabel()
        .find('.js-label-text')
        .text(),
    ).toEqual('Milestone');
  });

  it('renders upcoming release badge', () => {
    const releaseClone = JSON.parse(JSON.stringify(release));
    releaseClone.upcoming_release = true;

    factory(releaseClone);

    expect(wrapper.text()).toContain('Upcoming Release');
  });

  it('slugifies the tag_name before setting it as the elements ID', () => {
    const releaseClone = JSON.parse(JSON.stringify(release));
    releaseClone.tag_name = 'a dangerous tag name <script>alert("hello")</script>';

    factory(releaseClone);

    expect(wrapper.attributes().id).toBe('a-dangerous-tag-name-script-alert-hello-script-');
  });

  describe('anchor scrolling', () => {
    beforeEach(() => {
      scrollToElement.mockClear();
    });

    const hasTargetBlueBackground = () => wrapper.classes('bg-line-target-blue');

    it('does not attempt to scroll the page if no anchor tag is included in the URL', () => {
      mockLocationHash = '';
      factory(release);

      expect(scrollToElement).not.toHaveBeenCalled();
    });

    it("does not attempt to scroll the page if the anchor tag doesn't match the release's tag name", () => {
      mockLocationHash = 'v0.4';
      factory(release);

      expect(scrollToElement).not.toHaveBeenCalled();
    });

    it("attempts to scroll itself into view if the anchor tag matches the release's tag name", () => {
      mockLocationHash = release.tag_name;
      factory(release);

      expect(scrollToElement).toHaveBeenCalledTimes(1);
      expect(scrollToElement).toHaveBeenCalledWith(wrapper.element);
    });

    it('renders with a light blue background if it is the target of the anchor', () => {
      mockLocationHash = release.tag_name;
      factory(release);

      return wrapper.vm.$nextTick().then(() => {
        expect(hasTargetBlueBackground()).toBe(true);
      });
    });

    it('does not render with a light blue background if it is not the target of the anchor', () => {
      mockLocationHash = '';
      factory(release);

      return wrapper.vm.$nextTick().then(() => {
        expect(hasTargetBlueBackground()).toBe(false);
      });
    });
  });
});
